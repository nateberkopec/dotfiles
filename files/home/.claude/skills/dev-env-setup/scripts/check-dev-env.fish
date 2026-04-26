#!/usr/bin/env fish
# check-dev-env.fish - Audit a project directory for standard dev environment compliance.
# Usage: fish check-dev-env.fish [directory]
# Exits 0 if compliant, 1 if issues found.

set target_dir (realpath (string trim -- (test (count $argv) -gt 0; and echo $argv[1]; or echo .)))

if not test -d "$target_dir"
    echo "Error: $target_dir is not a directory" >&2
    exit 2
end

set failures
set warnings
set passes

function check_pass
    set -a passes "$argv[1]"
    if command -q gum
        gum style --foreground 2 "  PASS  $argv[1]"
    else
        echo "  PASS  $argv[1]"
    end
end

function check_fail
    set -a failures "$argv[1]|$argv[2]"
    if command -q gum
        gum style --foreground 1 "  FAIL  $argv[1]"
    else
        echo "  FAIL  $argv[1]"
    end
end

function check_warn
    set -a warnings "$argv[1]|$argv[2]"
    if command -q gum
        gum style --foreground 3 "  WARN  $argv[1]"
    else
        echo "  WARN  $argv[1]"
    end
end

# Header
echo ""
if command -q gum
    gum style --bold --border double --padding "0 2" "Dev Environment Audit: $target_dir"
else
    echo "=== Dev Environment Audit: $target_dir ==="
end
echo ""

# --- Check 1: mise config exists ---
set mise_file ""
if test -f "$target_dir/mise.toml"
    set mise_file "$target_dir/mise.toml"
    check_pass "mise config (mise.toml)"
else if test -f "$target_dir/mise.local.toml"
    set mise_file "$target_dir/mise.local.toml"
    check_pass "mise config (mise.local.toml)"
else if test -f "$target_dir/.mise.toml"
    set mise_file "$target_dir/.mise.toml"
    check_pass "mise config (.mise.toml)"
else
    check_fail "mise config" "Create mise.toml (your repo) or mise.local.toml (others' repo) with [tools] and [tasks] sections."
end

# --- Check 2: mise tasks ---
# Use `mise tasks` if mise is available, otherwise parse the toml
set has_test 0
set has_lint 0
set has_complexity 0
set has_serve_or_dev 0
set has_build 0

if test -n "$mise_file"
    # Check for tasks by parsing the toml file for [tasks.*] headers and task.*.run patterns
    set task_names

    # Look for [tasks.NAME] sections and tasks with run/depends keys
    for line in (cat "$mise_file")
        # Match [tasks.foo] or [tasks."foo:bar"]
        if string match -rq '^\[tasks[.\[]["\']*([a-zA-Z0-9_:.-]+)' -- "$line"
            set -a task_names (string match -r '^\[tasks[.\[]["\']*([a-zA-Z0-9_:.-]+)' -- "$line")[2]
        end
    end

    # Also try `mise tasks` in the directory if mise is available
    if command -q mise
        set mise_task_output (builtin cd "$target_dir"; and mise tasks 2>/dev/null)
        for line in $mise_task_output
            set task_name (string split -m1 " " -- "$line")[1]
            if test -n "$task_name"
                set -a task_names "$task_name"
            end
        end
    end

    for t in $task_names
        switch "$t"
            case test
                set has_test 1
            case lint 'lint:*'
                set has_lint 1
                if test "$t" = "lint:complexity"
                    set has_complexity 1
                end
            case complexity
                set has_complexity 1
            case serve dev
                set has_serve_or_dev 1
            case build
                set has_build 1
        end
    end
end

if test $has_test -eq 1
    check_pass "mise task: test"
else
    check_fail "mise task: test" "Add a [tasks.test] section to run the test suite."
end

if test $has_lint -eq 1
    check_pass "mise task: lint"
else
    check_fail "mise task: lint" "Add a [tasks.lint] section to run linters."
end

if test $has_serve_or_dev -eq 1
    check_pass "mise task: serve/dev"
else
    # This is a warning, not all projects have servers
    check_warn "mise task: serve/dev" "Add a [tasks.serve] or [tasks.dev] section if this project has a server."
end

if test $has_build -eq 1
    check_pass "mise task: build"
else
    check_warn "mise task: build" "Add a [tasks.build] section if this project produces build artifacts."
end

set ruby_project_files (find "$target_dir" -maxdepth 1 -type f \( -name Gemfile -o -name "*.gemspec" -o -name .ruby-version -o -name Rakefile \) 2>/dev/null)
set is_ruby_project 0
if test (count $ruby_project_files) -gt 0
    set is_ruby_project 1
end

if test $is_ruby_project -eq 1
    if test $has_complexity -eq 1
        check_pass "mise task: lint:complexity"
    else
        check_fail "mise task: lint:complexity" "Add a [tasks.\"lint:complexity\"] section. For RuboCop projects, run Metrics/PerceivedComplexity; otherwise run a custom changed-file complexity linter."
    end
end

# --- Check 3: hk config exists ---
set hk_file ""
if test -f "$target_dir/hk.pkl"
    set hk_file "$target_dir/hk.pkl"
    check_pass "hk config (hk.pkl)"
else if test -f "$target_dir/hk.toml"
    set hk_file "$target_dir/hk.toml"
    check_pass "hk config (hk.toml)"
else if test -d "$target_dir/.hk"
    set hk_file "$target_dir/.hk"
    check_pass "hk config (.hk/)"
else
    check_fail "hk config" "Create hk.pkl with pre-commit hooks for lint and test. See: https://hk.jdx.dev/"
end

# --- Check 4: pre-commit hooks include lint and test ---
set has_precommit_lint 0
set has_precommit_complexity 0
set has_precommit_test 0

if test -n "$hk_file"; and test -f "$hk_file"
    set hk_contents (cat "$hk_file")

    # Check for lint-related steps in pre-commit
    if string match -rq '(lint|standard|eslint|rubocop|clippy|ruff|biome)' -- "$hk_contents"
        set has_precommit_lint 1
    end

    # Check for complexity step in pre-commit
    if string match -rq 'mise run lint:complexity' -- "$hk_contents"
        set has_precommit_complexity 1
    end

    # Check for test-related steps in pre-commit
    if string match -rq '(test|spec|check)' -- "$hk_contents"
        set has_precommit_test 1
    end
end

if test -n "$hk_file"
    if test $has_precommit_lint -eq 1
        check_pass "pre-commit: lint step"
    else
        check_fail "pre-commit: lint step" "Add a lint step to pre-commit in hk config. Use: check = \"mise run lint\""
    end

    if test $is_ruby_project -eq 1
        if test $has_precommit_complexity -eq 1
            check_pass "pre-commit: complexity step"
        else
            check_fail "pre-commit: complexity step" "Add a pre-commit step to hk config. Use: check = \"mise run lint:complexity\""
        end
    end

    if test $has_precommit_test -eq 1
        check_pass "pre-commit: test step"
    else
        check_fail "pre-commit: test step" "Add a test step to pre-commit in hk config. Use: check = \"mise run test\""
    end
end

# --- Check 5: hk hooks are installed ---
if test -d "$target_dir/.git"
    # hk installs itself as the hooks path or puts scripts in .git/hooks
    set hooks_path (git -C "$target_dir" config core.hooksPath 2>/dev/null)

    if test -n "$hooks_path"
        check_pass "hk hooks installed (core.hooksPath = $hooks_path)"
    else if test -x "$target_dir/.git/hooks/pre-commit"
        # Check if the hook references hk
        if string match -q '*hk*' -- (cat "$target_dir/.git/hooks/pre-commit" 2>/dev/null)
            check_pass "hk hooks installed"
        else
            check_warn "hk hooks installed" "Run 'hk install' to activate git hooks."
        end
    else
        check_fail "hk hooks installed" "Run 'hk install' in the project directory to activate git hooks."
    end
else
    check_warn "hk hooks installed" "Not a git repository - cannot check hook installation."
end

# --- Check 6: git cleanliness (dev env files not dirtying git status) ---
if test -d "$target_dir/.git"
    # Dev env files that should never appear as untracked/modified
    set dev_env_files mise.local.toml .mise.local.toml hk.pkl hk.toml hk.local.pkl

    # Get untracked and modified files from git status
    set dirty_files (git -C "$target_dir" status --porcelain 2>/dev/null | string replace -r '^.. ' '')

    set dirty_dev_files
    for df in $dirty_files
        for ef in $dev_env_files
            if test "$df" = "$ef"
                set -a dirty_dev_files "$df"
            end
        end
    end

    if test (count $dirty_dev_files) -eq 0
        check_pass "git clean (no dev env files in git status)"
    else
        set dirty_list (string join ", " $dirty_dev_files)
        check_fail "git clean ($dirty_list visible in git status)" "Add these to .git/info/exclude: $dirty_list"
    end
end

# --- Summary ---
echo ""

set num_passes (count $passes)
set num_failures (count $failures)
set num_warnings (count $warnings)
set total_checks (math $num_passes + $num_failures + $num_warnings)

if test $num_failures -eq 0
    set summary "All clear! $total_checks checks passed ($num_warnings warnings)."
    if command -q gum
        gum style --bold --foreground 2 --border rounded --padding "0 2" "$summary"
    else
        echo "$summary"
    end
    echo ""
    exit 0
else
    set summary "$num_failures issues found out of $total_checks checks."
    if command -q gum
        gum style --bold --foreground 1 --border rounded --padding "0 2" "$summary"
    else
        echo "$summary"
    end
    echo ""

    if command -q gum
        gum style --bold "Next actions:"
    else
        echo "Next actions:"
    end
    for f in $failures
        set parts (string split "|" -- "$f")
        echo "  - $parts[1]: $parts[2]"
    end

    if test $num_warnings -gt 0
        echo ""
        if command -q gum
            gum style --bold "Warnings (may not apply):"
        else
            echo "Warnings (may not apply):"
        end
        for w in $warnings
            set parts (string split "|" -- "$w")
            echo "  - $parts[1]: $parts[2]"
        end
    end

    echo ""
    exit 1
end
