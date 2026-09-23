#!/usr/bin/env bash
set -euo pipefail

base="${1:?usage: check_dependency_repair_loop.sh BASE PR_HEAD EVENT}"
pr_head="${2-}"
event="${3:?usage: check_dependency_repair_loop.sh BASE PR_HEAD EVENT}"

if [ "$event" != "workflow_run" ]; then
    exit 0
fi
for commit in "$base" "$pr_head"; do
    if [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]] || ! git cat-file -e "$commit^{commit}"; then
        echo "Expected an available commit SHA: $commit" >&2
        exit 1
    fi
done
if ! git merge-base --is-ancestor "$base" "$pr_head"; then
    echo "PR head $pr_head does not descend from comparison base $base" >&2
    exit 1
fi

message="Regenerate mise.lock with native provenance verification"
record="41898282+github-actions[bot]@users.noreply.github.com"$'\t'"$message"
rewrites="$(git log --format='%ae%x09%s' "$base..$pr_head" | grep -Fxc "$record" || true)"
if [ "$rewrites" -ge 2 ]; then
    echo "::error::Bailing out after $rewrites native lock rewrites. Preserve the dependency branch for manual diagnosis; do not repair or snooze updates to force success. See #702." >&2
    exit 1
fi
