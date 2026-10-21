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
The temporary Node eMudhra TLS workaround expired on 2026-11-20.
Reassess Node's bundled CA store against https://emudhra.we-have-a-problem.com/.
Remove the workaround if default Node rejects both compromised chains, or extend this deadline after review.
EOF
exit 1
