#!/bin/bash
# Phase progress for bin/dotf. Phases run in the current shell so exports
# persist and set -e still stops at the first failing command.

DOTF_PHASE=""

dotf_epoch_ms() {
    local now
    now="$(date +%s%N)"
    case "$now" in
        *N) printf '%s\n' "$(( ${now%N} * 1000 ))" ;;
        *) printf '%s\n' "${now:0:${#now}-6}" ;;
    esac
}

dotf_format_duration() {
    local ms="$1"
    if [ "$ms" -lt 1000 ]; then
        printf '%sms\n' "$ms"
    else
        printf '%d.%ds\n' $((ms / 1000)) $((ms % 1000 / 100))
    fi
}

run_phase() {
    local name="$1" start elapsed
    shift
    DOTF_PHASE="$name"
    echo "▸ $name"
    start="$(dotf_epoch_ms)"
    "$@"
    elapsed="$(dotf_format_duration $(($(dotf_epoch_ms) - start)))"
    DOTF_PHASE=""
    debug "Phase $name took $elapsed"
    echo "✓ $name ($elapsed)"
}

report_failed_phase() {
    [ -n "$DOTF_PHASE" ] || return 0
    echo "✗ $DOTF_PHASE failed" >&2
    debug "Phase $DOTF_PHASE failed"
}
