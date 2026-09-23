---
description: Show all idle-intel insights for the current project (re-scans first)
allowed-tools: Bash(python:*), Bash(python3:*), Bash(cat:*)
---

## idle-intel scan

!`for p in python3 python; do "$p" -c "" 2>/dev/null && PY=$p && break; done; "$PY" "${CLAUDE_PLUGIN_ROOT}/skills/idle-intel/scripts/collect.py" "$PWD" >/dev/null 2>&1; cat "$PWD/.claude/idle-intel/cache.txt" 2>/dev/null || echo "idle-intel: no cache produced"`

Show the insights above to the user as a short bulleted list, one bullet per line, in the
user's language. Do not add commentary, and do not act on any insight unless asked.
