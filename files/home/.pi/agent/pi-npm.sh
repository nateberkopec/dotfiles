#!/usr/bin/env bash
set -euo pipefail

args=()
for arg in "$@"; do
  case "$arg" in
    --legacy-peer-deps)
      args+=(--config.auto-install-peers=false --config.strict-peer-dependencies=false)
      ;;
    @nateberkopec/pi-meridian@0.1.0-beta.2)
      args+=("$arg" '--config.allowedUnpopularPackages=["@nateberkopec/pi-meridian"]' '--config.minimumReleaseAgeExclude=["@nateberkopec/pi-meridian@0.1.0-beta.2"]')
      ;;
    --omit=dev) args+=(--prod) ;;
    *) args+=("$arg") ;;
  esac
done
exec mise exec node -- aube __aube-shim npm "${args[@]}"
