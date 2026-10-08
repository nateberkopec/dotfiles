#!/usr/bin/env bash
set -euo pipefail

args=()
for arg in "$@"; do
  case "$arg" in
    --legacy-peer-deps)
      args+=(--config.auto-install-peers=false --config.strict-peer-dependencies=false)
      ;;
    *) args+=("$arg") ;;
  esac
done
exec mise exec node -- aube __aube-shim npm "${args[@]}"
