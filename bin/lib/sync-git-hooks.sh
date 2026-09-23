#!/bin/bash

# Sync global hooks separately from mise's whole-home copy. Some machines have
# an externally managed, read-only hooks directory; leave it untouched there.

set -u

source_dir="$HOME/.dotfiles/files/home/.git-hooks"
target_dir="$HOME/.git-hooks"

notice() {
    printf 'dotfiles: skipping git hook sync; %s\n' "$1" >&2
}

if ! mkdir -p "$target_dir" 2>/dev/null; then
    notice "$target_dir cannot be created"
    exit 0
fi

for source in "$source_dir"/*; do
    [ -f "$source" ] || continue

    name="$(basename "$source")"
    temporary="$(mktemp "$target_dir/.dotfiles-$name.XXXXXX" 2>/dev/null)" || {
        notice "$target_dir is not writable"
        exit 0
    }

    if cp -p "$source" "$temporary" 2>/dev/null && mv -f "$temporary" "$target_dir/$name" 2>/dev/null; then
        continue
    fi

    rm -f "$temporary" 2>/dev/null || true
    notice "$target_dir/$name cannot be replaced"
done
