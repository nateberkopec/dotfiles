#!/bin/bash

# Pre-defaults hook for `mise bootstrap` (see [bootstrap.hooks] in
# files/home/.config/mise/config.toml). Marks drift before the defaults phase
# runs so the post-defaults hook can relaunch affected apps only when
# something actually changed.

set -e

[ "$(uname -s)" = "Darwin" ] || exit 0

if ! mise bootstrap macos defaults status --missing >/dev/null 2>&1; then
    touch "${TMPDIR:-/tmp}/dotf-defaults-changed"
fi
