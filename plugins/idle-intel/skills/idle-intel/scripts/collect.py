#!/usr/bin/env python3
"""idle-intel collector: gathers useful micro-facts about the current project
and writes them to a cache file, one insight per line.

Zero third-party dependencies. All external tools (npm, pip, git, cargo)
are optional; each check is skipped silently if the tool or manifest is absent.

Usage:  python3 collect.py [project_dir]
Cache:  <project_dir>/.claude/idle-intel/cache.txt
"""

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

TIMEOUT = 25  # seconds per external command
MAX_ITEMS_PER_SOURCE = 3


def run(cmd, cwd):
    """Run a command, return stdout or None. Never raises."""
    try:
        from shutil import which as _w
        exe = _w(cmd[0])
        if exe is None:
            return None
        p = subprocess.run(
            [exe] + list(cmd[1:]), cwd=cwd, capture_output=True, text=True, timeout=TIMEOUT
        )
        return p.stdout
    except Exception:
        return None


def which(tool):
    from shutil import which as _w
    return _w(tool) is not None


# ---------------------------------------------------------------- collectors

def npm_intel(root):
    lines = []
    if not (root / "package.json").exists() or not which("npm"):
        return lines

    # security audit -- the highest-value insight
    out = run(["npm", "audit", "--json"], root)
    if out:
        try:
            data = json.loads(out)
            sev = data.get("metadata", {}).get("vulnerabilities", {})
            crit = sev.get("critical", 0)
            high = sev.get("high", 0)
            mod = sev.get("moderate", 0)
            if crit or high:
                lines.append(
                    f"npm audit: {crit} critical, {high} high severity vulns -> run `npm audit fix`"
                )
            elif mod:
                lines.append(f"npm audit: {mod} moderate vulns, nothing critical")
            else:
                lines.append("npm audit: 0 known vulnerabilities. Clean.")
        except (json.JSONDecodeError, AttributeError):
            pass

    # outdated deps
    out = run(["npm", "outdated", "--json"], root)
    if out and out.strip():
        try:
            data = json.loads(out)
            majors = []
            for name, info in data.items():
                cur, latest = info.get("current"), info.get("latest")
                if cur and latest and cur.split(".")[0] != latest.split(".")[0]:
                    majors.append(f"{name} {cur}->{latest}")
            for m in majors[:MAX_ITEMS_PER_SOURCE]:
                lines.append(f"major update available: {m}")
            rest = len(data) - len(majors)
            if rest > 0:
                lines.append(f"{rest} minor/patch dep updates pending")
        except json.JSONDecodeError:
            pass
    return lines


def python_intel(root):
    lines = []
    has_py = (root / "requirements.txt").exists() or (root / "pyproject.toml").exists()
    if not has_py or not which("pip"):
        return lines
    out = run(["pip", "list", "--outdated", "--format=json"], root)
    if out:
        try:
            data = json.loads(out)
            for pkg in data[:MAX_ITEMS_PER_SOURCE]:
                lines.append(
                    f"pip: {pkg['name']} {pkg['version']} -> {pkg['latest_version']} available"
                )
            if len(data) > MAX_ITEMS_PER_SOURCE:
                lines.append(f"pip: {len(data)} outdated packages total")
        except (json.JSONDecodeError, KeyError):
            pass
    return lines


def git_intel(root):
    lines = []
    if not (root / ".git").exists() or not which("git"):
        return lines

    out = run(["git", "log", "--oneline", "@{u}..HEAD"], root)
    if out is not None:
        n = len(out.strip().splitlines()) if out.strip() else 0
        if n > 0:
            lines.append(f"git: {n} unpushed commit{'s' if n > 1 else ''} on this branch")

    out = run(["git", "stash", "list"], root)
    if out and out.strip():
        n = len(out.strip().splitlines())
        lines.append(f"git: {n} stash{'es' if n > 1 else ''} sitting around -- still needed?")

    out = run(
        ["git", "for-each-ref", "--sort=committerdate",
         "--format=%(refname:short)|%(committerdate:unix)", "refs/heads/"],
        root,
    )
    if out:
        cutoff = time.time() - 30 * 86400
        stale = [
            l.split("|")[0] for l in out.strip().splitlines()
            if "|" in l and l.split("|")[1].isdigit() and int(l.split("|")[1]) < cutoff
        ]
        if stale:
            n = len(stale)
            lines.append(
                f"git: {n} branch{'es' if n > 1 else ''} untouched for 30+ days (e.g. {stale[0]})"
            )
    return lines


def todo_intel(root):
    lines = []
    exts = {".py", ".js", ".ts", ".jsx", ".tsx", ".go", ".rs", ".java", ".rb", ".c", ".cpp", ".h"}
    skip_dirs = {"node_modules", ".git", "dist", "build", "venv", ".venv", "__pycache__", "target"}
    todo, fixme = 0, 0
    pat = re.compile(r"\b(TODO|FIXME)\b")
    count = 0
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in skip_dirs]
        for f in filenames:
            if Path(f).suffix not in exts:
                continue
            count += 1
            if count > 2000:  # keep it fast on huge repos
                break
            try:
                text = (Path(dirpath) / f).read_text(errors="ignore")
                for m in pat.finditer(text):
                    if m.group(1) == "TODO":
                        todo += 1
                    else:
                        fixme += 1
            except OSError:
                continue
    if fixme:
        lines.append(f"{fixme} FIXME markers in the codebase -- oldest debts bite hardest")
    if todo:
        lines.append(f"{todo} TODO markers across the project")
    return lines


def size_intel(root):
    lines = []
    nm = root / "node_modules"
    if nm.exists():
        try:
            size = sum(f.stat().st_size for f in nm.rglob("*") if f.is_file())
            gb = size / 1e9
            if gb > 1:
                lines.append(f"node_modules weighs {gb:.1f} GB")
        except OSError:
            pass
    return lines


# ------------------------------------------------------------------- main

def main():
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()
    cache_dir = root / ".claude" / "idle-intel"
    cache_dir.mkdir(parents=True, exist_ok=True)

    insights = []
    for collector in (npm_intel, python_intel, git_intel, todo_intel, size_intel):
        try:
            insights.extend(collector(root))
        except Exception:
            continue  # a broken collector must never break the pipeline

    if not insights:
        insights = ["idle-intel: project scanned, nothing urgent found"]

    cache = cache_dir / "cache.txt"
    tmp = cache_dir / "cache.txt.tmp"
    tmp.write_text("\n".join(insights) + "\n")
    tmp.replace(cache)  # atomic swap: statusline never reads a half-written file
    print(f"idle-intel: {len(insights)} insights cached in {cache}")


if __name__ == "__main__":
    main()
