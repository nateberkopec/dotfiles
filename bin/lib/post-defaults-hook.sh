#!/bin/bash

# Post-defaults hook for `mise bootstrap` (see [bootstrap.hooks] in
# files/home/.config/mise/config.toml). Writes defaults mise can't express
# declaratively (values needing $HOME expansion) and relaunches the apps that
# read changed defaults.

set -e

[ "$(uname -s)" = "Darwin" ] || exit 0

restart_ui=false

screenshot_location="$HOME/Documents/Inbox"
if [ "$(defaults read com.apple.screencapture location 2>/dev/null)" != "$screenshot_location" ]; then
    defaults write com.apple.screencapture location "$screenshot_location"
    restart_ui=true
fi

if [ -f "${TMPDIR:-/tmp}/dotf-defaults-changed" ]; then
    rm -f "${TMPDIR:-/tmp}/dotf-defaults-changed"
    killall Dock 2>/dev/null || true
    killall Finder 2>/dev/null || true
    restart_ui=true
fi

if [ "$restart_ui" = true ]; then
    killall SystemUIServer 2>/dev/null || true
fi
