#!/bin/bash
set -e

REPO_PATH=${1:?Usage: ralph.sh <repo_path> <prd.md> [max_iterations] [test_cmd]}
PRD_FILE=${2:?Usage: ralph.sh <repo_path> <prd.md> [max_iterations] [test_cmd]}
MAX_ITERATIONS=${3:-10}
TEST_CMD=${4:-}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RALPH_DIR="/tmp/ralph/$(uuidgen)"
mkdir -p "$RALPH_DIR"
cp "$PRD_FILE" "$RALPH_DIR/prd.md"
echo "# Ralph Progress Log" > "$RALPH_DIR/progress.txt"
sed "s|<RALPH_DIR>|$RALPH_DIR|g" "$SCRIPT_DIR/prompt.md" > "$RALPH_DIR/prompt.md"

BRANCH=$(grep -m1 '^Branch:' "$RALPH_DIR/prd.md" | sed 's/Branch: *`\{0,1\}\([^`]*\)`\{0,1\}/\1/')
[ -z "$BRANCH" ] && echo "No Branch: found in PRD" && exit 1

cd "$REPO_PATH"
CURRENT=$(git branch --show-current)
if [ "$CURRENT" != "$BRANCH" ]; then
  git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"
fi

echo "Ralph: $RALPH_DIR"

print_learnings() {
  echo "=== Learnings ==="
  cat "$RALPH_DIR/progress.txt"
}

for i in $(seq 1 $MAX_ITERATIONS); do
  OUTPUT=$(cd "$REPO_PATH" && OPENCODE_PERMISSION='"allow"' opencode run \
    -f "$RALPH_DIR/prompt.md" 2>&1 | tee /dev/stderr) || true

  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    if [ -n "$TEST_CMD" ]; then
      if (cd "$REPO_PATH" && $TEST_CMD); then
        print_learnings
        exit 0
      else
        cd "$REPO_PATH" && git reset --hard HEAD~1
        continue
      fi
    fi
    print_learnings
    exit 0
  fi
  sleep 2
done

print_learnings
exit 1
