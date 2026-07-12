#!/usr/bin/env bash
# idle-intel statusline for Claude Code.
# Reads the intel cache and prints ONE rotating insight (changes every 12s).
# FAST PATH: pure bash, no python -- python only runs in the background refresh.
# Works on Linux, macOS, and Windows (Git Bash / MINGW).

INPUT=$(cat 2>/dev/null)

# Extract current_dir (or cwd) from Claude Code's session JSON with sed only
DIR=$(printf '%s' "$INPUT" | sed -n 's/.*"current_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -z "$DIR" ] && DIR=$(printf '%s' "$INPUT" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
DIR=${DIR//\\\\/\\}   # unescape JSON backslashes (Windows paths)
[ -z "$DIR" ] && DIR="$PWD"

CACHE="$DIR/.claude/idle-intel/cache.txt"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Background refresh if cache missing or older than 30 minutes.
# python3 on Linux/macOS, python on Windows -- detected once here, off the fast path.
if [ ! -f "$CACHE" ] || [ -n "$(find "$CACHE" -mmin +30 2>/dev/null)" ]; then
  PY=$(command -v python3 || command -v python)
  [ -n "$PY" ] && (nohup "$PY" "$SELF_DIR/collect.py" "$DIR" >/dev/null 2>&1 &)
fi

if [ ! -f "$CACHE" ]; then
  echo "◈ idle-intel: first scan running..."
  exit 0
fi

# Rotate: new insight every 12 seconds, cycling through all cached lines
N=$(wc -l < "$CACHE" | tr -d ' ')
[ "$N" -eq 0 ] && { echo "◈ idle-intel: cache empty"; exit 0; }
IDX=$(( ( $(date +%s) / 12 ) % N + 1 ))
LINE=$(sed -n "${IDX}p" "$CACHE")

echo "◈ $LINE"
