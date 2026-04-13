#!/bin/bash

set -euo pipefail

repo_dir="${1:-$PWD}"
output_log="$repo_dir/output.log"
fish_log="$repo_dir/fish-init.log"

run_dotfiles() {
    cd "$repo_dir"
    chmod +x bin/dotf
    ./bin/dotf run 2>&1 | tee "$output_log"
}

find_fish_bin() {
    local candidates=()

    if [ "$(uname -s)" = "Darwin" ]; then
        candidates=(
            "$HOME/.homebrew/bin/fish"
            "/opt/homebrew/bin/fish"
            "/usr/local/bin/fish"
        )
    else
        candidates=("fish")
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
    if grep -q -e "Debian packages not installed" -e "Debian Packages Not Found" "$output_log"; then
        echo "Skipping fish check due to missing Debian packages."
        return 0
    fi

    echo "Starting fish shell to check for initialization errors..."

    local fish_bin
    fish_bin="$(find_fish_bin)" || {
        echo "❌ Fish shell not found"
        return 1
    }

    "$fish_bin" -c 'echo "Fish shell initialized successfully"' 2>&1 | tee "$fish_log"
    echo "✅ Fish shell started without errors"
}

run_dotfiles
check_fish
