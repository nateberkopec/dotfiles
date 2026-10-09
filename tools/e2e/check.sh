#!/bin/bash
set -euo pipefail

export DOTF_E2E_LOG_DIR="${1:?usage: check.sh LOG_DIR}"
export PATH="$HOME/.local/bin:$PATH"
cd "$HOME/.dotfiles"
mise exec -- bundle exec rake test:e2e
