#!/usr/bin/env bash
# Regenerate the managed mise.lock entries for the platform this machine runs on.
# mise verifies provenance cryptographically only for its current platform, so
# refusing to cross-generate keeps every provenance_verified entry native.
set -euo pipefail

platform="${1:?usage: lock_native_platform.sh PLATFORM}"
root="$(cd "$(dirname "$0")/../.." && pwd)"

case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) native="linux-x64" ;;
    Darwin-arm64) native="macos-arm64" ;;
    *) native="unsupported" ;;
esac
if [ "$platform" != "$native" ]; then
    echo "Refusing to generate $platform lock entries on $native" >&2
    exit 1
fi

version="$(tr -d '[:space:]' < "$root/config/mise.version")"
mise_bin="$HOME/.local/bin/mise"
if [ "$("$mise_bin" --version 2>/dev/null | awk 'NR == 1 { print $1 }')" != "$version" ]; then
    curl -fsSL https://mise.run | MISE_VERSION="$version" MISE_INSTALL_PATH="$mise_bin" sh
fi

MISE_GLOBAL_CONFIG_FILE="$root/files/home/.config/mise/config.toml" "$mise_bin" lock --global --platform "$platform"
