#!/usr/bin/env bash
# make-demo.sh -- builds a disposable demo project to test idle-intel against.
# Everything is created inside ./idle-intel-demo ; delete the folder to undo.
#
# The demo deliberately contains EVERY defect the collectors detect, so the
# expected output is known in advance:
#   1. npm audit: 1 high severity vuln        (lodash 4.17.15, real CVE)
#   2. major update available: lodash          (4.x -> latest is still 4.x, shows as pending update)
#   3. git: 2 unpushed commits
#   4. git: 1 stash sitting around
#   5. git: 1 branch untouched for 30+ days   (backdated commit)
#   6. 2 FIXME markers
#   7. 3 TODO markers

set -e
ROOT="$PWD/idle-intel-demo"
[ -d "$ROOT" ] && { echo "idle-intel-demo already exists here. Delete it first."; exit 1; }

echo "== Building demo project in $ROOT"
mkdir -p "$ROOT/src"
cd "$ROOT"

# --- source files with known TODO/FIXME counts -----------------------------
cat > src/app.js <<'EOF'
// TODO: extract config to env
// FIXME: race condition on concurrent writes
function main() {
  // TODO: add input validation
  return process(load());
}
EOF
cat > src/utils.js <<'EOF'
// TODO: replace with native structuredClone
// FIXME: leaks listeners on hot reload
module.exports = { clone: (x) => JSON.parse(JSON.stringify(x)) };
EOF

# --- git repo with fake remote, unpushed commits, stash, stale branch ------
git init -q
git config user.email demo@idle-intel.test
git config user.name "idle-intel demo"

# fake "remote" = local bare repo, so @{u} exists without any network
git init -q --bare ../idle-intel-demo-remote.git
git remote add origin ../idle-intel-demo-remote.git

DATE60=$(python3 -c "import datetime as d; print((d.datetime.now()-d.timedelta(days=60)).strftime('%Y-%m-%dT%H:%M:%S'))")
DATE45=$(python3 -c "import datetime as d; print((d.datetime.now()-d.timedelta(days=45)).strftime('%Y-%m-%dT%H:%M:%S'))")

git add -A
GIT_AUTHOR_DATE="$DATE60" GIT_COMMITTER_DATE="$DATE60" git commit -qm "initial commit"
git branch -M main
git push -qu origin main

# stale branch: last commit backdated 45 days
git checkout -qb old-experiment
echo "// abandoned" >> src/utils.js
git add -A
GIT_AUTHOR_DATE="$DATE45" GIT_COMMITTER_DATE="$DATE45" git commit -qm "experiment"
git checkout -q main

# two unpushed commits on main
echo "// v2" >> src/app.js && git add -A && git commit -qm "wip 1"
echo "// v3" >> src/app.js && git add -A && git commit -qm "wip 2"

# one stash
echo "// uncommitted idea" >> src/utils.js
git stash -q

# --- npm project with a real known-vulnerable dependency -------------------
cat > package.json <<'EOF'
{
  "name": "idle-intel-demo",
  "version": "1.0.0",
  "private": true,
  "dependencies": { "lodash": "4.17.15" }
}
EOF
echo "-- running npm install (needed for npm audit; ~30s)..."
npm install --silent --no-fund --no-audit

echo ""
echo "== Demo ready. Now run the test:"
echo "   bash /path/to/idle-intel/scripts/test.sh $ROOT"
echo ""
echo "== Expected insights (verify each one appears in the cache):"
echo "   - npm audit: high severity vulns (lodash CVE)"
echo "   - git: 2 unpushed commits"
echo "   - git: 1 stash"
echo "   - git: 1 branch untouched 30+ days (old-experiment)"
echo "   - 2 FIXME markers, 3 TODO markers"
echo ""
echo "== Cleanup when done:"
echo "   rm -rf $ROOT ${ROOT}-remote.git"
