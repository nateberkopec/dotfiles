function check_hk_config
    if test -f "$target_dir/hk.pkl"
        set -g hk_file "$target_dir/hk.pkl"
        check_pass "hk config (hk.pkl)"
    else if test -f "$target_dir/hk.toml"
        set -g hk_file "$target_dir/hk.toml"
        check_pass "hk config (hk.toml)"
    else if test -d "$target_dir/.hk"
        set -g hk_file "$target_dir/.hk"
        check_pass "hk config (.hk/)"
    else
        check_fail "hk config" "Create hk.pkl with pre-commit hooks for lint and test. See: https://hk.jdx.dev/"
    end
end

function check_hk_precommit
    collect_hk_flags

    if test -z "$hk_file"
        return
    end

    report_flag has_precommit_lint "pre-commit: lint step" check_fail "Add a lint step to pre-commit in hk config. Use: check = \"mise run lint\""
    report_flag has_precommit_test "pre-commit: test step" check_fail "Add a test step to pre-commit in hk config. Use: check = \"mise run test\""
end

function collect_hk_flags
    set -g has_precommit_lint 0
    set -g has_precommit_test 0

    if test -z "$hk_file"; or not command -q hk
        return
    end

    set -l plan_output (builtin cd "$target_dir"; and hk run pre-commit --all --plan --json 2>/dev/null)
    if test $status -ne 0
        return
    end

    set -l step_name ""
    for line in $plan_output
        set -l name_match (string match -r '"name": "([^"]+)"' -- "$line")
        if test (count $name_match) -gt 1
            set step_name $name_match[2]
            continue
        end

        if test -n "$step_name"; and string match -rq '"status": "included"' -- "$line"
            collect_hk_step_flag "$step_name"
            set step_name ""
        end
    end
end

function collect_hk_step_flag
    set -l step_name $argv[1]

    if string match -rq '(^|[-_:])(lint|standard|eslint|rubocop|clippy|ruff|biome)($|[-_:])' -- "$step_name"
        set -g has_precommit_lint 1
    end
    if string match -rq '(^|[-_:])(test|spec|check)($|[-_:])' -- "$step_name"
        set -g has_precommit_test 1
    end
end
