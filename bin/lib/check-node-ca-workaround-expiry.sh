#!/usr/bin/env bash
set -euo pipefail

expires=20261120
today=${1:-$(date -u +%Y%m%d)}

if [[ ! $today =~ ^[0-9]{8}$ ]]; then
  printf 'Invalid date: %s\n' "$today" >&2
  exit 2
fi

if ((10#$today < 10#$expires)); then
  exit 0
fi

cat >&2 <<'EOF'
The temporary eMudhra TLS workarounds expired on 2026-11-20.
Reassess Node's bundled CA store and the need to filter /etc/ssl/cert.pem against https://emudhra.we-have-a-problem.com/.
Remove the workarounds that are no longer needed, or extend this deadline after review.
EOF
exit 1
