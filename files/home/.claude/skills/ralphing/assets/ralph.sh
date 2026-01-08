#!/bin/bash
set -e

REPO_PATH=${1:?Usage: ralph.sh <repo_path> <prd.md> [max_iterations] [test_cmd]}
PRD_FILE=${2:?Usage: ralph.sh <repo_path> <prd.md> [max_iterations] [test_cmd]}
MAX_ITERATIONS=${3:-10}
TEST_CMD=${4:-}

RALPH_DIR="/tmp/ralph/$(uuidgen)"
mkdir -p "$RALPH_DIR"
cp "$PRD_FILE" "$RALPH_DIR/prd.md"
echo "# Ralph Progress Log" > "$RALPH_DIR/progress.txt"
sed "s|<RALPH_DIR>|$RALPH_DIR|g" "$(dirname "$0")/prompt.md" > "$RALPH_DIR/prompt.md"

BRANCH=$(grep -oP '(?<=^Branch: `)[^`]+' "$RALPH_DIR/prd.md" || grep -oP '(?<=^Branch: )\S+' "$RALPH_DIR/prd.md")
[ -z "$BRANCH" ] && echo "No Branch: found in PRD" && exit 1

cd "$REPO_PATH"
[ "$(git branch --show-current)" != "$BRANCH" ] && git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"

echo "Ralph: $RALPH_DIR"

for i in $(seq 1 $MAX_ITERATIONS); do
  PREV_LINES=$(wc -l < "$RALPH_DIR/progress.txt")

  OUTPUT=$(OPENCODE_PERMISSION='{"*":"allow","external_directory":"allow"}' opencode run \
    "$(cat "$RALPH_DIR/prompt.md")" 2>&1 | tee /dev/stderr) || true

  tail -n +$((PREV_LINES + 1)) "$RALPH_DIR/progress.txt"

  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    [ -z "$TEST_CMD" ] && exit 0
    if $TEST_CMD; then
      exit 0
    else
      git reset --hard HEAD~1
      continue
    fi
  fi
  sleep 2
done

exit 1
