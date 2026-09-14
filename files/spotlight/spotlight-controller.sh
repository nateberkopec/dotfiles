#!/bin/sh
set -eu

PATH=/usr/bin:/bin:/usr/sbin:/sbin
STATE_DIR=__STATE_DIR__
PAUSE_FILE="$STATE_DIR/pause-until"
VOLUMES="__VOLUMES__"
EXCLUSIONS="__EXCLUSIONS__"

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Spotlight changes require administrator authentication; run with sudo." >&2
    exit 1
  fi
}

set_indexing() {
  desired=$1
  for volume in $VOLUMES; do
    status=$(mdutil -s "$volume")
    case "$desired:$status" in
      off:*enabled*) mdutil -i off "$volume" ;;
      on:*disabled*) mdutil -i on "$volume" ;;
      off:*disabled*|on:*enabled*) : ;;
      *) echo "Unexpected indexing status for $volume: $status" >&2; exit 1 ;;
    esac
  done
}

pause_active() {
  [ -f "$PAUSE_FILE" ] || return 1
  deadline=$(cat "$PAUSE_FILE")
  case "$deadline" in
    *[!0-9]*|'') echo "Invalid pause deadline in $PAUSE_FILE" >&2; exit 1 ;;
  esac
  now=$(date +%s)
  if [ "$deadline" -gt "$now" ]; then
    return 0
  fi
  rm -f "$PAUSE_FILE"
  return 1
}

reconcile() {
  if pause_active; then
    set_indexing off
    return
  fi

  power=$(pmset -g batt | head -n 1)
  case "$power" in
    *"Battery Power"*) set_indexing off ;;
    *"AC Power"*) set_indexing on ;;
    *) echo "Unable to determine power source: $power" >&2; exit 1 ;;
  esac
}

pause() {
  duration=${1:-24h}
  case "$duration" in
    *h) amount=${duration%h}; multiplier=3600 ;;
    *m) amount=${duration%m}; multiplier=60 ;;
    *d) amount=${duration%d}; multiplier=86400 ;;
    *) echo "Duration must end in m, h, or d (for example: 30m, 24h, 2d)." >&2; exit 2 ;;
  esac
  case "$amount" in
    *[!0-9]*|'') echo "Duration must contain a positive whole number." >&2; exit 2 ;;
  esac
  [ "$amount" -gt 0 ] || { echo "Duration must be greater than zero." >&2; exit 2; }

  mkdir -p "$STATE_DIR"
  chmod 700 "$STATE_DIR"
  umask 077
  deadline=$(($(date +%s) + amount * multiplier))
  temporary="$PAUSE_FILE.$$"
  printf '%s\n' "$deadline" > "$temporary"
  mv "$temporary" "$PAUSE_FILE"
  reconcile
}

status() {
  if pause_active; then
    echo "Policy: paused until $(date -r "$(cat "$PAUSE_FILE")")"
  else
    power=$(pmset -g batt | head -n 1)
    echo "Policy: automatic ($power)"
  fi
  for volume in $VOLUMES; do mdutil -s "$volume"; done
}

audit() {
  echo "Declared folder exclusions (manual Search Privacy configuration required):"
  for path in $EXCLUSIONS; do echo "  $path"; done
  echo
  echo "Effective Spotlight volume configuration:"
  mdutil -P /System/Volumes/Data
  echo
  echo "The Exclusions array above is authoritative. This audit does not infer exclusion"
  echo "from an empty mdfind result or from indexing being disabled."
}

require_root
case "${1:-}" in
  reconcile) reconcile ;;
  pause) pause "${2:-24h}" ;;
  resume) rm -f "$PAUSE_FILE"; reconcile ;;
  status) status ;;
  audit) audit ;;
  *) echo "Usage: $0 {reconcile|pause [30m|24h|2d]|resume|status|audit}" >&2; exit 2 ;;
esac
