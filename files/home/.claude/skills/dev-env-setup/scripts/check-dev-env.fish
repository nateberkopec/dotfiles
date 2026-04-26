#!/usr/bin/env fish
# check-dev-env.fish - Audit a project directory for standard dev environment compliance.
# Usage: fish check-dev-env.fish [directory]
# Exits 0 if compliant, 1 if issues found.

set script_dir (dirname (realpath (status --current-filename)))
set lib_dir "$script_dir/check-dev-env"

for file in \
    context.fish \
    output.fish \
    parsing.fish \
    tooling.fish \
    mise-config.fish \
    env.fish \
    mise-tasks.fish \
    mise-task-checks.fish \
    ruby.fish \
    hk.fish \
    hk-reporting.fish \
    git.fish \
    summary.fish
    source "$lib_dir/$file"
end

init_check_context $argv
print_header

check_mise_config
check_env_files
check_mise_tasks
check_hk_config
check_hk_precommit
check_hk_installed
check_git_cleanliness

print_summary
