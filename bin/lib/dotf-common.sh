#!/bin/bash
# Shared helpers for bin/dotf and bin/bootstrap.
#
# Source this file from either script. It must not depend on any variables
# defined by the sourcing script, so it can be loaded early.

# Print HH:MM:SS.mmm for log lines. GNU and current BSD date support %N;
# older BSD date prints a literal N, so fall back to whole seconds.
dotf_timestamp() {
    local now
    now="$(date +%H:%M:%S.%N)"
    case "$now" in
        *N) printf '%s.000\n' "${now%.N}" ;;
        *) printf '%s\n' "${now:0:12}" ;;
    esac
}

# Noninteractive runs never prompt. They apply user-level setup only unless
# sudo already works without a password. CI can still exercise package
# installation without opting into this partial-run mode.
dotf_noninteractive() {
    [ -n "${NONINTERACTIVE:-}" ]
}

dotf_defers_privileged_work() {
    dotf_noninteractive && ! (sudo -n true) >/dev/null 2>&1
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
