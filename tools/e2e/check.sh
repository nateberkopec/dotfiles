#!/bin/bash
set -euo pipefail

export DOTF_E2E_LOG_DIR="${1:?usage: check.sh LOG_DIR TEST_DIR}"
test_dir="${2:?usage: check.sh LOG_DIR TEST_DIR}"
export PATH="$HOME/.local/bin:$PATH"
cd "$HOME/.dotfiles"
mise exec -- bundle exec ruby -e 'ARGV.each { |file| require file }' "$test_dir"/*_test.rb
