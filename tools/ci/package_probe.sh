#!/bin/bash
trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s\n' "$value"
}
csv_items() {
    local value="${1:-}"
    local item
    local items=()
    [ -n "$value" ] || return 0
    IFS=',' read -r -a items <<< "$value"
    for item in "${items[@]}"; do
        item="$(trim "$item")"
        [ -n "$item" ] && printf '%s\n' "$item"
    done
}
find_candidate() {
    local candidate
    for candidate in "$@"; do
        [ -x "$candidate" ] && printf '%s\n' "$candidate" && return 0
    done
    return 1
}
find_brew_bin() {
    if command -v brew >/dev/null 2>&1; then
        command -v brew
        return 0
    fi
    find_candidate "$HOME/.homebrew/bin/brew" /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew
}
find_mise_bin() {
    if command -v mise >/dev/null 2>&1; then
        command -v mise
        return 0
    fi
    find_candidate "$HOME/.local/bin/mise" "$HOME/.homebrew/bin/mise" /opt/homebrew/bin/mise /usr/local/bin/mise
}
brew_formula_installed() {
    local brew_bin
    brew_bin="$(find_brew_bin)" || return 1
    "$brew_bin" list --formula "$1" >/dev/null 2>&1
}
brew_cask_installed() {
    local brew_bin
    brew_bin="$(find_brew_bin)" || return 1
    "$brew_bin" list --cask "$1" >/dev/null 2>&1
}
debian_package_installed() { dpkg -s "$1" >/dev/null 2>&1; }
snap_package_installed() { command -v snap >/dev/null 2>&1 && snap list "$1" >/dev/null 2>&1; }
non_apt_package_installed() { command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1; }
mise_tool_installed() {
    local mise_bin
    mise_bin="$(find_mise_bin)" || return 1
    "$mise_bin" --cd "$HOME" where "$1" >/dev/null 2>&1
}
assert_not_installed() {
    if "$3" "$2"; then
        echo "❌ $1 '$2' was already installed before the integration run"
        return 1
    fi
    echo "✅ $1 '$2' was not installed before the integration run"
}
assert_installed() {
    if "$3" "$2"; then
        echo "✅ $1 '$2' was installed by the integration run"
        return 0
    fi
    echo "❌ $1 '$2' was not installed by the integration run"
    return 1
}
check_env_packages() {
    local label="$1" env_name="$2" check_function="$3" assert_function="$4" item
    while IFS= read -r item; do
        "$assert_function" "$label" "$item" "$check_function"
    done < <(csv_items "${!env_name-}")
}
check_ci_packages() {
    local phase="$1" assert_function="$2"
    if [ "$(uname -s)" = "Darwin" ]; then
        check_env_packages "Homebrew formula" BREW_CI_PACKAGES brew_formula_installed "$assert_function"
        check_env_packages "Homebrew cask" BREW_CI_CASKS brew_cask_installed "$assert_function"
    elif [ "$(uname -s)" = "Linux" ]; then
        check_env_packages "Debian package" DEBIAN_CI_PACKAGES debian_package_installed "$assert_function"
        check_env_packages "Debian non-APT package" DEBIAN_CI_NON_APT_PACKAGES non_apt_package_installed "$assert_function"
        check_env_packages "Snap package" DEBIAN_CI_SNAP_PACKAGES snap_package_installed "$assert_function"
    fi
    check_env_packages "mise tool" MISE_CI_TOOLS mise_tool_installed "$assert_function"
    echo "✅ $phase package checks passed"
}
