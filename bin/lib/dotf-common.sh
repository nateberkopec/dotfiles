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
