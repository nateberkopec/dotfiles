function check_mise_tasks
    collect_mise_task_flags
    report_standard_mise_tasks
    check_long_mise_run_blocks
    detect_ruby_project
    check_ruby_mise_tasks
    check_mise_modern_features
end

function collect_mise_task_flags
    for flag in test lint complexity dead_code flog flay serve_or_dev serve_task build
        set -g has_$flag 0
    end

    if test -z "$mise_file"
        return
    end

    for task_name in (mise_task_names)
        mark_mise_task "$task_name"
    end
end

function mark_mise_task
    set task_name $argv[1]
    switch "$task_name"
        case test
            set -g has_test 1
        case lint 'lint:*'
            set -g has_lint 1
        case serve dev
            set -g has_serve_or_dev 1
            if test "$task_name" = "serve"
                set -g has_serve_task 1
            end
        case build
            set -g has_build 1
    end

    set normalized_task_name (string replace -r '^lint:' '' -- "$task_name")
    if contains -- "$normalized_task_name" complexity dead-code flog flay
        set flag_name (string replace -- - _ "$normalized_task_name")
        set -g has_$flag_name 1
    end
end

function report_standard_mise_tasks
    report_flag has_test "mise task: test" check_fail "Add a [tasks.test] section to run the test suite."
    if test $has_test -eq 1
        check_test_runtime
    end

    report_flag has_lint "mise task: lint" check_fail "Add a [tasks.lint] section to run linters."
    report_serve_task
    report_build_task
end

function check_mise_modern_features
    if test -z "$mise_file"
        return
    end

    check_shell_alias_preference

    if test $is_ruby_project -eq 1
        check_mise_task_sources
        check_ruby_dependency_prep
    end
end

function check_shell_alias_preference
    if mise_file_has_section hooks.enter
        check_warn "mise shell aliases" "Prefer [shell_alias] for project aliases; reserve [hooks.enter] for shell code that cannot be expressed as aliases."
    else
        check_pass "mise shell aliases"
    end
end

function check_mise_task_sources
    set checked_tasks
    for task_name in (mise_task_names | sort -u)
        switch "$task_name"
            case test 'lint:*'
                set -a checked_tasks "$task_name"
                if mise_task_has_key "$task_name" sources
                    check_pass "mise task sources: $task_name"
                else
                    check_warn "mise task sources: $task_name" "Add sources = [...] so mise can skip unchanged lint/test tasks during pre-commit."
                end
        end
    end

    if test (count $checked_tasks) -eq 0
        check_warn "mise task sources" "Add sources = [...] to Ruby lint/test tasks so pre-commit can skip unchanged checks."
    end
end

function check_ruby_dependency_prep
    if mise_file_has_section deps.bundler; or mise_file_has_section prepare.bundler
        check_pass "mise deps: bundler"
    else
        check_warn "mise deps: bundler" "Prefer [deps.bundler] with auto = true over manual setup tasks that run bundle install."
    end
end
