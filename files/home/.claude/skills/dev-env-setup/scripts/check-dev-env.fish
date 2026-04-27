#!/usr/bin/env fish
# check-dev-env.fish - Audit a project directory for standard dev environment compliance.
# Usage: fish check-dev-env.fish [directory]
# Exits 0 if compliant, 1 if issues found.

set script_dir (dirname (realpath (status --current-filename)))
set lib_dir "$script_dir/check-dev-env"

for file in context output parsing tooling mise-config env secrets mise-tasks mise-task-checks ruby hk hk-reporting git summary
    source "$lib_dir/$file.fish"
end

init_check_context $argv
print_header

for check in check_mise_config check_env_files check_secrets check_mise_tasks check_hk_config check_hk_precommit check_hk_installed check_git_cleanliness
    $check
end

print_summary
