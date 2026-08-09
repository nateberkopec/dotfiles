#!/bin/bash
# Shared helpers for bin/dotf and bin/bootstrap.
#
# Source this file from either script. It must not depend on any variables
# defined by the sourcing script, so it can be loaded early.

# Print a timestamp using gdate (GNU coreutils) when available, otherwise
# fall back to BSD date. The first argument is the GNU format string; the
# optional second argument is the POSIX fallback format used when gdate is
# absent (defaults to the GNU format). This is the single place that decides
# whether to use gdate, so the macOS/BSD fallback lives in one spot.
dotf_date() {
    local gnu_format="$1"
    local posix_format="${2:-$gnu_format}"
    if command -v gdate &> /dev/null; then
        gdate "+$gnu_format"
    else
        date "+$posix_format"
    fi
}

# Run a command quietly unless DEBUG=true.
stdout_quiet_unless_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        "$@"
    else
        "$@" >/dev/null
    fi
}

# Return success when the first numeric dotted version is newer than the second.
dotf_version_is_newer() {
    local candidate="${1#v}"
    local current="${2#v}"
    local candidate_parts current_parts index candidate_part current_part

    IFS=. read -r -a candidate_parts <<< "$candidate"
    IFS=. read -r -a current_parts <<< "$current"
    for index in 0 1 2; do
        candidate_part="${candidate_parts[$index]:-0}"
        current_part="${current_parts[$index]:-0}"
        if ((10#$candidate_part > 10#$current_part)); then
            return 0
        elif ((10#$candidate_part < 10#$current_part)); then
            return 1
        fi
    done
    return 1
}
