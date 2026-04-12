#!/bin/bash
set -e

SCRIPT_DIR="$(dirname "$0")"

case "${1:-}" in
  start)
    REPO_PATH=${2:?Usage: ralph.sh start <repo_path> <prd.md> [max_iterations] [test_cmd]}
    PRD_FILE=${3:?Usage: ralph.sh start <repo_path> <prd.md> [max_iterations] [test_cmd]}
    MAX_ITERATIONS=${4:-10}
    TEST_CMD=${5:-}

    RALPH_DIR="/tmp/ralph/$(uuidgen)"
    mkdir -p "$RALPH_DIR"
    cp "$PRD_FILE" "$RALPH_DIR/prd.md"
    echo "# Ralph Progress Log" > "$RALPH_DIR/progress.txt"
    echo "0" > "$RALPH_DIR/iteration"
    echo "running" > "$RALPH_DIR/status"
    echo "$REPO_PATH" > "$RALPH_DIR/repo_path"
    echo "$MAX_ITERATIONS" > "$RALPH_DIR/max_iterations"
    echo "$TEST_CMD" > "$RALPH_DIR/test_cmd"
    sed "s|<RALPH_DIR>|$RALPH_DIR|g" "$SCRIPT_DIR/prompt.md" > "$RALPH_DIR/prompt.md"

    BRANCH=$(sed -n 's/^Branch: `\([^`]*\)`$/\1/p' "$RALPH_DIR/prd.md" | head -1)
    [ -z "$BRANCH" ] && BRANCH=$(sed -n 's/^Branch: \([^ ]*\)$/\1/p' "$RALPH_DIR/prd.md" | head -1)
    [ -z "$BRANCH" ] && echo "No Branch: found in PRD" && exit 1
    echo "$BRANCH" > "$RALPH_DIR/branch"

    cd "$REPO_PATH"
    if [ "$(git branch --show-current)" != "$BRANCH" ]; then
      git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"
    fi

    nohup "$SCRIPT_DIR/ralph.sh" _run "$RALPH_DIR" > "$RALPH_DIR/output.log" 2>&1 &
    echo "$!" > "$RALPH_DIR/pid"

    echo "$RALPH_DIR"
    ;;

  status)
    RALPH_DIR=${2:?Usage: ralph.sh status <ralph_dir>}
    [ ! -d "$RALPH_DIR" ] && echo "Session not found: $RALPH_DIR" && exit 1

    STATUS=$(cat "$RALPH_DIR/status")
    ITERATION=$(cat "$RALPH_DIR/iteration")
    MAX=$(cat "$RALPH_DIR/max_iterations")

    echo "status: $STATUS"
    echo "iteration: $ITERATION/$MAX"
    echo "--- progress ---"
    cat "$RALPH_DIR/progress.txt"
    echo "--- output (last 5 lines) ---"
    tail -5 "$RALPH_DIR/output.log" 2>/dev/null || echo "(no output yet)"
    ;;

  _run)
    RALPH_DIR=${2:?}
    REPO_PATH=$(cat "$RALPH_DIR/repo_path")
    MAX_ITERATIONS=$(cat "$RALPH_DIR/max_iterations")
    TEST_CMD=$(cat "$RALPH_DIR/test_cmd")

    cd "$REPO_PATH"

    for i in $(seq 1 $MAX_ITERATIONS); do
      echo "$i" > "$RALPH_DIR/iteration"
      echo "=== Iteration $i ===" >> "$RALPH_DIR/output.log"

      OPENCODE_PERMISSION='{"*":"allow","external_directory":"allow"}' opencode run \
        "$(cat "$RALPH_DIR/prompt.md")" 2>&1 | tee -a "$RALPH_DIR/output.log"
      OUTPUT=$(tail -1000 "$RALPH_DIR/output.log")

      if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
        if [ -n "$TEST_CMD" ] && ! $TEST_CMD; then
          git reset --hard HEAD~1
          continue
        fi
        if ! grep -q '\- \[ \]' "$RALPH_DIR/prd.md"; then
          echo "complete" > "$RALPH_DIR/status"
          exit 0
        fi
      fi
      sleep 2
    done

    echo "failed" > "$RALPH_DIR/status"
    exit 1
    ;;

  *)
    echo "Usage: ralph.sh <command> [args]"
    echo "Commands:"
    echo "  start <repo_path> <prd.md> [max_iterations] [test_cmd]  Start a new ralph session"
    echo "  status <ralph_dir>                                      Check session status"
    exit 1
    ;;
esac
