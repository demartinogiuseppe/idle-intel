#!/usr/bin/env bash
# idle-intel test drive -- verifies everything WITHOUT touching ~/.claude/settings.json
# Usage: bash test.sh [project_dir]     (defaults to current directory)

set -u
DIR="${1:-$PWD}"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== idle-intel test drive on: $DIR"
echo ""
echo "-- Step 1/3: running collector (this is the slow path, done in background normally)"
PY=$(command -v python3 || command -v python)
"$PY" "$SELF_DIR/collect.py" "$DIR" || { echo "FAIL: collector error"; exit 1; }

echo ""
echo "-- Step 2/3: full cache content:"
cat "$DIR/.claude/idle-intel/cache.txt"

echo ""
echo "-- Step 3/3: simulating the status line for 36 seconds (one insight every 12s):"
for i in 1 2 3; do
  echo "{\"workspace\":{\"current_dir\":\"$DIR\"}}" | bash "$SELF_DIR/statusline.sh"
  [ "$i" -lt 3 ] && sleep 12
done

echo ""
echo "-- Speed check (must be well under 300ms):"
start=$(date +%s%N)
echo "{\"workspace\":{\"current_dir\":\"$DIR\"}}" | bash "$SELF_DIR/statusline.sh" > /dev/null
end=$(date +%s%N)
echo "statusline exec: $(( (end-start)/1000000 )) ms"

echo ""
echo "== All good. To wire it into Claude Code for real, add to ~/.claude/settings.json:"
echo '   "statusLine": { "type": "command", "command": "'"$SELF_DIR"'/statusline.sh" }'
echo "== To undo: just remove that block. Nothing else was modified."
