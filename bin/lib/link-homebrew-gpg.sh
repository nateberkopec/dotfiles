#!/bin/bash

set -e

[ "$(uname -s)" = "Darwin" ] || exit 0
[ -x /opt/homebrew/bin/gpg ] || exit 0

target="$HOME/.local/bin/gpg"
if [ -e "$target" ] && [ ! -L "$target" ]; then
    printf 'Keeping existing non-symlink %s\n' "$target"
    exit 0
fi

mkdir -p "$HOME/.local/bin"
ln -sfn /opt/homebrew/bin/gpg "$target"
