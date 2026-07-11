#!/bin/bash

# Pre-dotfiles hook for `mise bootstrap` (see [bootstrap.hooks] in
# files/home/.config/mise/config.toml). The Protect Files / Protect Git Hooks
# steps mark some managed files immutable; strip the flags only when the repo
# copy differs so mise's dotfiles phase can overwrite them. The protect steps
# re-apply the flags afterwards.

set -e

[ "$(uname -s)" = "Darwin" ] || exit 0

DOTFILES_HOME="$HOME/.dotfiles/files/home"

managed_protected_files=(
    ".gem/credentials"
    ".git-hooks/pre-commit"
    ".git-hooks/pre-push"
    ".pi/agent/extensions/find_timeout.ts"
)

for relative in "${managed_protected_files[@]}"; do
    target="$HOME/$relative"
    source="$DOTFILES_HOME/$relative"
    [ -f "$target" ] && [ -f "$source" ] || continue
    cmp -s "$target" "$source" && continue

    chflags nouchg "$target" 2>/dev/null ||
        sudo chflags noschg,nouchg "$target"
done
