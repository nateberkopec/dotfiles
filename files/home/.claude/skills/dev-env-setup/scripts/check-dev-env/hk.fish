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
    report_flag has_precommit_large_files "pre-commit: large-files step" check_fail "Add a pre-commit step to hk config. Use: check = \"mise run lint:large-files\""

    if test $is_ruby_project -eq 1
        report_flag has_precommit_complexity "pre-commit: complexity step" check_fail "Add a pre-commit step to hk config. Use: check = \"mise run lint:complexity\""
        report_flag has_precommit_dead_code "pre-commit: dead-code step" check_fail "Add a pre-commit step to hk config. Use: check = \"mise run lint:dead-code\""
        report_flag has_precommit_flog "pre-commit: flog step" check_fail "Add a pre-commit step to hk config. Use: check = \"mise run lint:flog\""
        report_flag has_precommit_flay "pre-commit: flay step" check_fail "Add a pre-commit step to hk config. Use: check = \"mise run lint:flay\""
    end

    report_flag has_precommit_test "pre-commit: test step" check_fail "Add a test step to pre-commit in hk config. Use: check = \"mise run test\""
end

function collect_hk_flags
    for flag in lint large_files complexity dead_code flog flay test
        set -g has_precommit_$flag 0
    end

    if test -z "$hk_file"; or not test -f "$hk_file"
        return
    end

    set hk_contents (cat "$hk_file")
    set_hk_flag has_precommit_lint '(lint|standard|eslint|rubocop|clippy|ruff|biome)' "$hk_contents"
    set_hk_flag has_precommit_large_files 'mise run lint:large-files' "$hk_contents"
    set_hk_flag has_precommit_complexity 'mise run lint:complexity' "$hk_contents"
    set_hk_flag has_precommit_dead_code 'mise run lint:dead-code' "$hk_contents"
    set_hk_flag has_precommit_flog 'mise run lint:flog' "$hk_contents"
    set_hk_flag has_precommit_flay 'mise run lint:flay' "$hk_contents"
    set_hk_flag has_precommit_test '(test|spec|check)' "$hk_contents"
end
