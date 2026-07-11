#!/bin/bash

set -euo pipefail

repo_dir="${1:-$PWD}"
fish_log="$repo_dir/fish-init.log"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=tools/ci/package_probe.sh
source "$script_dir/package_probe.sh"

trim_mise_config() {
    if [ -n "${MISE_CI_TOOLS:-}${BREW_CI_PACKAGES:-}${DEBIAN_CI_PACKAGES:-}" ]; then
        ruby "$script_dir/trim_mise_config.rb"
    fi
}

run_dotfiles() {
    local log_name="${1:-output.log}"

    cd "$repo_dir"
    chmod +x bin/dotf
    ./bin/dotf run 2>&1 | tee "$repo_dir/$log_name"
}

assert_no_steps_ran() {
    local label="$1"
    local log_name="$2"
    local log_path="$repo_dir/$log_name"

    if grep -F "Running step:" "$log_path"; then
        echo "❌ $label was not a no-op when converged"
        return 1
    fi

    echo "✅ $label was a no-op when converged"
}

find_fish_bin() {
    local candidates=()

    if [ "$(uname -s)" = "Darwin" ]; then
        candidates=(
            "$HOME/.local/bin/fish"
            "$HOME/.homebrew/bin/fish"
            "/opt/homebrew/bin/fish"
            "/usr/local/bin/fish"
        )
    else
        candidates=("$HOME/.local/bin/fish" "fish")
    fi

    for candidate in "${candidates[@]}"; do
        if [[ "$candidate" == */* ]]; then
            if [ -x "$candidate" ]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        elif command -v "$candidate" >/dev/null 2>&1; then
            command -v "$candidate"
            return 0
        fi
    done

    if command -v fish >/dev/null 2>&1; then
        command -v fish
        return 0
    fi

    return 1
}

check_fish() {
    echo "Starting fish shell to check for initialization errors..."

    if command -v mise >/dev/null 2>&1 && mise --cd "$HOME" where aqua:fish-shell/fish-shell >/dev/null 2>&1; then
        mise --cd "$HOME" x aqua:fish-shell/fish-shell -- fish -c 'echo "Fish shell initialized successfully"' 2>&1 | tee "$fish_log"
    else
        local fish_bin
        fish_bin="$(find_fish_bin)" || {
            echo "❌ Fish shell not found"
            return 1
        }
        "$fish_bin" -c 'echo "Fish shell initialized successfully"' 2>&1 | tee "$fish_log"
    fi

    echo "✅ Fish shell started without errors"
}

trim_mise_config
check_ci_packages "Pre-run" assert_not_installed
run_dotfiles output.log
check_ci_packages "Post-run" assert_installed
run_dotfiles output-second.log
assert_no_steps_ran "Second dotf run" output-second.log
check_fish
