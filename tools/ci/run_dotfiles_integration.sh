#!/bin/bash

set -euo pipefail

repo_dir="${1:-$PWD}"
output_log="$repo_dir/output.log"
fish_log="$repo_dir/fish-init.log"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=tools/ci/package_probe.sh
source "$script_dir/package_probe.sh"

run_dotfiles() {
    cd "$repo_dir"
    chmod +x bin/dotf
    ./bin/dotf run 2>&1 | tee "$output_log"
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

    local fish_bin
    fish_bin="$(find_fish_bin)" || {
        echo "❌ Fish shell not found"
        return 1
    }

    "$fish_bin" -c 'echo "Fish shell initialized successfully"' 2>&1 | tee "$fish_log"
    echo "✅ Fish shell started without errors"
}

check_ci_packages "Pre-run" assert_not_installed
run_dotfiles
check_ci_packages "Post-run" assert_installed
check_fish
