#!/bin/bash

# Clear immutable flags left by older dotfiles versions before mise updates
# these managed files. This remains safe to run after the legacy flags are gone.

set -e

# shellcheck source=dotf-common.sh
source "$(dirname "${BASH_SOURCE[0]}")/dotf-common.sh"

[ "$(uname -s)" = "Darwin" ] || exit 0

DOTFILES_HOME="$HOME/.dotfiles/files/home"

managed_protected_files=(
    ".aws/credentials"
    ".gem/credentials"
    ".pi/agent/extensions/find_timeout.ts"
)

for relative in "${managed_protected_files[@]}"; do
    target="$HOME/$relative"
    source="$DOTFILES_HOME/$relative"
    [ -f "$target" ] && [ -f "$source" ] || continue

    if ! chflags noschg,nouchg "$target" 2>/dev/null; then
        if dotf_defers_privileged_work; then
            echo "Error: $target requires sudo to clear immutable flags; run dotf run first." >&2
            exit 1
        fi
        sudo chflags noschg,nouchg "$target"
    fi
done
