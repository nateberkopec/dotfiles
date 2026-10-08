#!/bin/bash
set -euo pipefail

# Exercise the CLI version whose positional-argument parser rejected our command.
case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)
        asset="herdr-linux-x86_64"
        checksum="18a8dc65f1c2fa485884344356dea1cfd911c6f06cf46fa78e193f4087f4dba7"
        ;;
    Darwin-arm64)
        asset="herdr-macos-aarch64"
        checksum="5173a3e0ae42d5d1ab7ebfa5d5e6329f7c3d23f8e1a3677c7ce3231da2884157"
        ;;
    Darwin-x86_64)
        asset="herdr-macos-x86_64"
        checksum="db62d548ff3e832b087a96b1894a08d26be3905f1830309cd556783f215d4054"
        ;;
    *) echo "Unsupported Herdr test platform" >&2; exit 1 ;;
esac

install_dir="${RUNNER_TEMP:?}/herdr-cli"
mkdir -p "$install_dir"
curl --fail --location --retry 3 "https://github.com/herdrdev/herdr/releases/download/v0.9.3/$asset" -o "$install_dir/herdr"
printf '%s  %s\n' "$checksum" "$install_dir/herdr" | shasum -a 256 -c -
chmod +x "$install_dir/herdr"
echo "$install_dir" >> "${GITHUB_PATH:?}"
