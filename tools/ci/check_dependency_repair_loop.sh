#!/usr/bin/env bash
set -euo pipefail

base="${1:?usage: check_dependency_repair_loop.sh BASE EVENT}"
event="${2:?usage: check_dependency_repair_loop.sh BASE EVENT}"

if [ "$event" != "workflow_run" ]; then
    exit 0
fi
if [[ ! "$base" =~ ^[0-9a-f]{40}$ ]]; then
    echo "Expected a commit SHA" >&2
    exit 1
fi

message="Regenerate mise.lock with native provenance verification"
record="41898282+github-actions[bot]@users.noreply.github.com"$'\t'"$message"
rewrites="$(git log --format='%ae%x09%s' "$base..HEAD" | grep -Fxc "$record" || true)"
if [ "$rewrites" -ge 2 ]; then
    echo "::error::Bailing out after $rewrites native lock rewrites. Preserve the dependency branch for manual diagnosis; do not repair or snooze updates to force success. See #702." >&2
    exit 1
fi
