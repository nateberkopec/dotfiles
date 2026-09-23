#!/usr/bin/env bash
# Validate the conditional lock jobs before reporting one required result.
set -euo pipefail

detect_result="${1-}"
lock_changed="${2-}"
linux_result="${3-}"
macos_result="${4-}"

fail() {
    echo "::error::Lock provenance workflow was not conclusive: $1" >&2
    exit 1
}

[ "$detect_result" = success ] || fail "change detection concluded '$detect_result'"

case "$lock_changed" in
    false)
        [ "$linux_result:$macos_result" = skipped:skipped ] ||
            fail "unchanged inputs unexpectedly produced linux=$linux_result macos=$macos_result"
        ;;
    true)
        [ "$linux_result:$macos_result" = success:success ] ||
            fail "changed inputs produced linux=$linux_result macos=$macos_result"
        ;;
    *)
        fail "change detection returned '$lock_changed' instead of true or false"
        ;;
esac

echo "Lock provenance workflow completed conclusively."
