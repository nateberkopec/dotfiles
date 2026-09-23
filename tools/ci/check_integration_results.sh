#!/usr/bin/env bash
set -euo pipefail

detection_result="${1:-}"
integration_optional="${2:-}"
platform_result="${3:-}"
non_admin_result="${4:-}"

if [ "$detection_result" != "success" ]; then
  echo "Change detection did not succeed: $detection_result" >&2
  exit 1
fi

case "$integration_optional" in
  true)
    expected_result=skipped
    ;;
  false)
    expected_result=success
    ;;
  *)
    echo "Change detection returned an unknown integration_optional value: $integration_optional" >&2
    exit 1
    ;;
esac

if [ "$platform_result" != "$expected_result" ] || [ "$non_admin_result" != "$expected_result" ]; then
  echo "Integration jobs must both be $expected_result: platform=$platform_result non-admin=$non_admin_result" >&2
  exit 1
fi
