#!/bin/bash

# Clear immutable flags left by older dotfiles versions before mise updates
# these managed files. This remains safe to run after the legacy flags are gone.

set -e

[ "$(uname -s)" = "Darwin" ] || exit 0

DOTFILES_HOME="$HOME/.dotfiles/files/home"

managed_protected_files=(
    ".aws/credentials"
    ".gem/credentials"
    ".git-hooks/pre-commit"
    ".git-hooks/pre-push"
    ".pi/agent/extensions/find_timeout.ts"
)

for relative in "${managed_protected_files[@]}"; do
    target="$HOME/$relative"
    source="$DOTFILES_HOME/$relative"
    [ -f "$target" ] && [ -f "$source" ] || continue

    chflags noschg,nouchg "$target" 2>/dev/null ||
        sudo chflags noschg,nouchg "$target"
done
