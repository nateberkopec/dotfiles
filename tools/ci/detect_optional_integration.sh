#!/usr/bin/env bash
set -euo pipefail

event_name="${1:?event name is required}"
base_sha="${2:-}"
head_sha="${3:-}"

case "$event_name" in
  pull_request|push)
    ;;
  *)
    echo "integration_optional=false" >> "$GITHUB_OUTPUT"
    exit 0
    ;;
esac

if [ -z "$base_sha" ] || [ -z "$head_sha" ] || [ "$base_sha" = "0000000000000000000000000000000000000000" ]; then
  echo "integration_optional=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

if [ "$event_name" = "pull_request" ]; then
  base_sha="$(git merge-base "$base_sha" "$head_sha")"
fi

git diff --name-only --no-renames "$base_sha" "$head_sha" > "$RUNNER_TEMP/changed-files"
files=()
while IFS= read -r file; do
  files+=("$file")
done < "$RUNNER_TEMP/changed-files"

if [ "${#files[@]}" -eq 0 ]; then
  echo "integration_optional=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

integration_optional=true

for file in "${files[@]}"; do
  case "$file" in
    test/*|docs/*|README.md|AGENTS.md|.agents/skills/*.md|files/home/.claude/CLAUDE.md|files/home/.claude/skills/*.md|files/home/.claude/skills/*/LICENSE.txt|files/home/.agents/*.md|files/home/.pi/agent/agents/*.md)
      ;;
    *)
      integration_optional=false
      break
      ;;
  esac
done

echo "integration_optional=$integration_optional" >> "$GITHUB_OUTPUT"
printf 'integration_optional=%s\n' "$integration_optional"
printf 'changed files:\n%s\n' "$(printf '%s\n' "${files[@]}")"
