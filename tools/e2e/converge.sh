#!/bin/bash
set -uo pipefail

source_dir="${1:?usage: converge.sh CHECKOUT LOG_DIR}"
log_dir="${2:?usage: converge.sh CHECKOUT LOG_DIR}"
mkdir -p "$log_dir" "$HOME/.dotfiles"
rsync -a --delete --exclude=/vendor --exclude=/node_modules --exclude=/logs --exclude=/tmp "$source_dir/" "$HOME/.dotfiles/" || exit 1
cd "$HOME/.dotfiles" || exit 1

converge() {
    local name="$1"; shift
    local start=$SECONDS
    env "$@" ./bin/dotf run > "$log_dir/$name.log" 2>&1 < /dev/null
    echo "$name: exit $? after $((SECONDS - start))s"
}

converge first-run
converge second-run DEBUG=true
