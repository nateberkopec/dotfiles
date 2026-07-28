#!/bin/bash

# Post-dotfiles hook for `mise bootstrap` (see [bootstrap.hooks] in
# files/home/.config/mise/config.toml). Links fish completions that ship
# inside OrbStack's app bundle — a conditional source mise's [dotfiles]
# entries can't express (they abort when a source is missing).

set -e

[ "$(uname -s)" = "Darwin" ] || exit 0

orbstack_completions="/Applications/OrbStack.app/Contents/Resources/completions/fish"
[ -d "$orbstack_completions" ] || exit 0

mkdir -p "$HOME/.config/fish/completions"
for name in docker kubectl orbctl; do
    source_path="$orbstack_completions/$name.fish"
    [ -e "$source_path" ] || continue
    ln -sfn "$source_path" "$HOME/.config/fish/completions/$name.fish"
done
