#!/usr/bin/env fish
# check-dev-env.fish - Audit a project directory for standard dev environment compliance.
# Usage: fish check-dev-env.fish [directory]
# Exits 0 if compliant, 1 if issues found.

set target_dir (realpath (string trim -- (test (count $argv) -gt 0; and echo $argv[1]; or echo .)))
set script_dir (dirname (realpath (status --current-filename)))

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

function env_file_keys
    set file $argv[1]
    if not test -f "$file"
        return 0
    end

    for line in (string split \n -- (cat "$file"))
        set trimmed (string trim -- "$line")
        if test -z "$trimmed"
            continue
        end
        if string match -q '#*' -- "$trimmed"
            continue
        end

        set matches (string match -r '^(?:export[ \t]+)?([A-Za-z_][A-Za-z0-9_]*)[ \t]*=' -- "$trimmed")
        if test (count $matches) -gt 1
            echo $matches[2]
        end
    end
end

function long_mise_task_run_blocks
    set file $argv[1]
    set current_task ""
    set in_run_block 0
    set run_task ""
    set run_lines 0

    while read -l line
        if test $in_run_block -eq 1
            set trimmed (string trim -- "$line")
            if test "$trimmed" = '"""'; or test "$trimmed" = "'''"
                if test $run_lines -gt 10
                    echo "$run_task|$run_lines"
                end
                set in_run_block 0
                set run_task ""
                set run_lines 0
            else
                set run_lines (math $run_lines + 1)
            end
            continue
        end

        set task_header (string match -r "^\\s*\\[tasks[.\\[]['\"]?([A-Za-z0-9_:.-]+)" -- "$line")
        if test (count $task_header) -gt 1
            set current_task $task_header[2]
        else if string match -rq "^\\s*\\[" -- "$line"
            set current_task ""
        end

        if test -n "$current_task"; and string match -rq "^\\s*run\\s*=\\s*([\"']{3})\\s*\$" -- "$line"
            set in_run_block 1
            set run_task "$current_task"
            set run_lines 0
        end
    end < "$file"
end

function check_test_runtime
    if not command -q mise
        check_warn "test task runtime <= 10s" "mise is not available, so the checker cannot time 'mise run test'."
        return
    end

    set started_at (date +%s)
    set test_output (builtin cd "$target_dir"; and mise run test 2>&1)
    set test_status $status
    set elapsed_seconds (math (date +%s) - $started_at)

    if test $test_status -ne 0
        set test_message (string join " " $test_output)
        check_fail "test task runs" "'mise run test' failed while checking runtime. $test_message"
    else if test $elapsed_seconds -gt 10
        check_warn "test task runtime <= 10s" "'mise run test' took "$elapsed_seconds"s. Acceptable remediations: run tests only for changed files; add/use a test:fast task that still covers 100% of unit-level app coverage; or keep this warning if neither approach can get under 10 seconds."
    else
        check_pass "test task runtime <= 10s"
    end
end

function check_shared_tool_symlink
    set tool_name $argv[1]
    set project_tool "$target_dir/tools/$tool_name"
    set skill_tool "$script_dir/$tool_name"

    if test -L "$project_tool"
        if test (realpath "$project_tool") = (realpath "$skill_tool")
            check_pass "shared tool symlink: $tool_name"
        else
            check_warn "shared tool symlink: $tool_name" "Prefer symlinking tools/$tool_name to $skill_tool instead of keeping a separate script."
        end
    else if test -e "$project_tool"
        check_warn "shared tool symlink: $tool_name" "tools/$tool_name exists but is not a symlink. Prefer symlinking to $skill_tool instead of copying the tool."
    else
        check_warn "shared tool symlink: $tool_name" "Prefer symlinking $skill_tool to tools/$tool_name instead of copying the tool."
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

# --- Check 2: .env loading and examples ---
set env_file "$target_dir/.env"
set env_example_file "$target_dir/.env.example"

if test -n "$mise_file"; and string match -rq "_.file\\s*=\\s*['\"]\\.env['\"]" -- (cat "$mise_file")
    check_pass "mise loads .env"
else
    check_fail "mise loads .env" "Add '[env]' with '_.file = \".env\"' to the mise config."
end

if test -f "$env_example_file"
    check_pass ".env.example exists"
else
    check_fail ".env.example exists" "Add a committed .env.example that documents required environment keys."
end

if test -d "$target_dir/.git"
    if git -C "$target_dir" ls-files --error-unmatch .env >/dev/null 2>/dev/null
        check_fail ".env not tracked" "Remove .env from git; commit .env.example instead."
    else
        check_pass ".env not tracked"
    end

    set env_status (git -C "$target_dir" status --porcelain -- .env 2>/dev/null)
    if test -z "$env_status"
        check_pass ".env ignored or absent from git status"
    else
        check_fail ".env ignored or absent from git status" "Add .env to .gitignore or .git/info/exclude."
    end
end

if test -f "$env_example_file"
    set example_keys (env_file_keys "$env_example_file" | sort -u)
    set env_keys (env_file_keys "$env_file" | sort -u)
    set missing_env_keys

    for key in $example_keys
        if not contains -- "$key" $env_keys
            set -a missing_env_keys "$key"
        end
    end

    if test (count $missing_env_keys) -eq 0
        check_pass ".env.example keys are in .env"
    else
        set missing_list (string join ", " $missing_env_keys)
        check_fail ".env.example keys are in .env" "Add missing keys to local .env or remove them from .env.example: $missing_list"
    end
end

# --- Check 3: mise tasks ---
# Use `mise tasks` if mise is available, otherwise parse the toml
set has_cloc_tool 0
set has_test 0
set has_lint 0
set has_large_files 0
set has_complexity 0
set has_dead_code 0
set has_flog 0
set has_flay 0
set has_serve_or_dev 0
set has_serve_task 0
set has_build 0

if test -n "$mise_file"
    if string match -rq '^\s*["\']github:aldanial/cloc["\']\s*=' -- (cat "$mise_file")
        set has_cloc_tool 1
    end

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
                if test "$t" = "lint:large-files"
                    set has_large_files 1
                else if test "$t" = "lint:complexity"
                    set has_complexity 1
                else if test "$t" = "lint:dead-code"
                    set has_dead_code 1
                else if test "$t" = "lint:flog"
                    set has_flog 1
                else if test "$t" = "lint:flay"
                    set has_flay 1
                end
            case large-files
                set has_large_files 1
            case complexity
                set has_complexity 1
            case dead-code
                set has_dead_code 1
            case flog
                set has_flog 1
            case flay
                set has_flay 1
            case serve dev
                set has_serve_or_dev 1
                if test "$t" = "serve"
                    set has_serve_task 1
                end
            case build
                set has_build 1
        end
    end
end

if test $has_test -eq 1
    check_pass "mise task: test"
    check_test_runtime
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

if test $has_serve_task -eq 1
    if not command -q ruby
        check_fail "serve task logs URL" "Ruby is required to run the serve URL checker."
    else
        set serve_url_output (ruby "$script_dir/check-serve-url.rb" "$target_dir" 2>&1)
        set serve_url_status $status
        if test $serve_url_status -eq 0
            check_pass "serve task logs URL"
        else
            set serve_url_message (string join " " $serve_url_output)
            check_fail "serve task logs URL" "Ensure 'mise run serve' logs a URL like http://localhost:4000 within the last 10 lines of output. $serve_url_message"
        end
    end
end

if test $has_build -eq 1
    check_pass "mise task: build"
else
    check_warn "mise task: build" "Add a [tasks.build] section if this project produces build artifacts."
end

if test -n "$mise_file"
    set long_run_blocks (long_mise_task_run_blocks "$mise_file")
    if test (count $long_run_blocks) -eq 0
        check_pass "mise task run blocks <= 10 lines"
    else
        set long_run_tasks
        for block in $long_run_blocks
            set parts (string split "|" -- "$block")
            set -a long_run_tasks "$parts[1] ($parts[2] lines)"
        end
        set long_run_list (string join ", " $long_run_tasks)
        check_fail "mise task run blocks <= 10 lines" "Move long task run blocks to separate scripts, e.g. bin/<task> or scripts/<task>, and have mise call the script: $long_run_list"
    end
end

if test $has_cloc_tool -eq 1
    check_pass "mise tool: cloc"
else
    check_fail "mise tool: cloc" "Add cloc from GitHub to the mise [tools] section for the large file LOC check: \"github:aldanial/cloc\" = \"latest\""
end

if test $has_large_files -eq 1
    check_pass "mise task: lint:large-files"
    check_shared_tool_symlink check_large_files.rb
else
    check_fail "mise task: lint:large-files" "Add a [tasks.\"lint:large-files\"] section that checks staged files crossing the LOC limit."
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

    if test $has_dead_code -eq 1
        check_pass "mise task: lint:dead-code"
        check_shared_tool_symlink check_dead_code.rb
    else
        check_fail "mise task: lint:dead-code" "Add a [tasks.\"lint:dead-code\"] section that runs debride for Ruby projects."
    end

    if test $has_flog -eq 1
        check_pass "mise task: lint:flog"
    else
        check_fail "mise task: lint:flog" "Add a [tasks.\"lint:flog\"] section that runs bundle exec rake flog for Ruby projects."
    end

    if test $has_flay -eq 1
        check_pass "mise task: lint:flay"
    else
        check_fail "mise task: lint:flay" "Add a [tasks.\"lint:flay\"] section that runs bundle exec rake flay for Ruby projects."
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
set has_precommit_large_files 0
set has_precommit_complexity 0
set has_precommit_dead_code 0
set has_precommit_flog 0
set has_precommit_flay 0
set has_precommit_test 0

if test -n "$hk_file"; and test -f "$hk_file"
    set hk_contents (cat "$hk_file")

    # Check for lint-related steps in pre-commit
    if string match -rq '(lint|standard|eslint|rubocop|clippy|ruff|biome)' -- "$hk_contents"
        set has_precommit_lint 1
    end

    # Check for large file step in pre-commit
    if string match -rq 'mise run lint:large-files' -- "$hk_contents"
        set has_precommit_large_files 1
    end

    # Check for complexity step in pre-commit
    if string match -rq 'mise run lint:complexity' -- "$hk_contents"
        set has_precommit_complexity 1
    end

    # Check for dead code step in pre-commit
    if string match -rq 'mise run lint:dead-code' -- "$hk_contents"
        set has_precommit_dead_code 1
    end

    # Check for flog/flay steps in pre-commit
    if string match -rq 'mise run lint:flog' -- "$hk_contents"
        set has_precommit_flog 1
    end
    if string match -rq 'mise run lint:flay' -- "$hk_contents"
        set has_precommit_flay 1
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

    if test $has_precommit_large_files -eq 1
        check_pass "pre-commit: large-files step"
    else
        check_fail "pre-commit: large-files step" "Add a pre-commit step to hk config. Use: check = \"mise run lint:large-files\""
    end

    if test $is_ruby_project -eq 1
        if test $has_precommit_complexity -eq 1
            check_pass "pre-commit: complexity step"
        else
            check_fail "pre-commit: complexity step" "Add a pre-commit step to hk config. Use: check = \"mise run lint:complexity\""
        end

        if test $has_precommit_dead_code -eq 1
            check_pass "pre-commit: dead-code step"
        else
            check_fail "pre-commit: dead-code step" "Add a pre-commit step to hk config. Use: check = \"mise run lint:dead-code\""
        end

        if test $has_precommit_flog -eq 1
            check_pass "pre-commit: flog step"
        else
            check_fail "pre-commit: flog step" "Add a pre-commit step to hk config. Use: check = \"mise run lint:flog\""
        end

        if test $has_precommit_flay -eq 1
            check_pass "pre-commit: flay step"
        else
            check_fail "pre-commit: flay step" "Add a pre-commit step to hk config. Use: check = \"mise run lint:flay\""
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
