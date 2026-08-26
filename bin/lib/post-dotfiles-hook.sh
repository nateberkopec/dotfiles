#!/bin/bash

# Post-dotfiles hook for `mise bootstrap` (see [bootstrap.hooks] in
# files/home/.config/mise/config.toml). Removes the legacy wallpaper agent
# before mise loads its replacement, then links fish completions that ship
# inside OrbStack's app bundle when available.

set -e

# Keep the browser revision aligned with mise's pinned Playwright CLI. The
# installer is a no-op when the matching browser is already cached.
mise exec -- playwright install chromium-headless-shell

[ "$(uname -s)" = "Darwin" ] || exit 0

legacy_wallpaper_label="com.user.woodblock-wallpaper"
launchctl bootout "gui/$(id -u)/$legacy_wallpaper_label" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$legacy_wallpaper_label.plist"

orbstack_completions="/Applications/OrbStack.app/Contents/Resources/completions/fish"
[ -d "$orbstack_completions" ] || exit 0

mkdir -p "$HOME/.config/fish/completions"
for name in docker kubectl orbctl; do
    source_path="$orbstack_completions/$name.fish"
    [ -e "$source_path" ] || continue
    ln -sfn "$source_path" "$HOME/.config/fish/completions/$name.fish"
done
