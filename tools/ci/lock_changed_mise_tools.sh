#!/usr/bin/env bash
set -euo pipefail

base="${1:?usage: lock_changed_mise_tools.sh BASE PLATFORM}"
platform="${2:?usage: lock_changed_mise_tools.sh BASE PLATFORM}"
root="$(cd "$(dirname "$0")/../.." && pwd)"

if targets_output="$(cd "$root" && bundle exec ruby tools/ci/mise_lock_targets.rb "$base")"; then
    :
else
    status=$?
    echo "Failed to select changed mise tools" >&2
    exit "$status"
fi

if [ -z "$targets_output" ]; then
    echo "No global mise pin changed; keeping unrelated lock entries intact."
    exit 0
fi

targets=()
while IFS= read -r tool; do
    targets+=("$tool")
done <<< "$targets_output"

bash "$root/tools/ci/lock_native_platform.sh" "$platform" "${targets[@]}"
