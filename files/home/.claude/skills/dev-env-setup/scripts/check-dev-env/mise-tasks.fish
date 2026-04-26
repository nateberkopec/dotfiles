function check_mise_tasks
    collect_mise_task_flags
    report_standard_mise_tasks
    check_long_mise_run_blocks
    check_large_file_tooling
    detect_ruby_project
    check_ruby_mise_tasks
end

function collect_mise_task_flags
    for flag in cloc_tool test lint large_files complexity dead_code flog flay serve_or_dev serve_task build
        set -g has_$flag 0
    end

    if test -z "$mise_file"
        return
    end

    if string match -rq '^\s*["\']github:aldanial/cloc["\']\s*=' -- (cat "$mise_file")
        set -g has_cloc_tool 1
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
            mark_lint_task "$task_name"
        case large-files
            set -g has_large_files 1
        case complexity
            set -g has_complexity 1
        case dead-code
            set -g has_dead_code 1
        case flog
            set -g has_flog 1
        case flay
            set -g has_flay 1
        case serve dev
            set -g has_serve_or_dev 1
            if test "$task_name" = "serve"
                set -g has_serve_task 1
            end
        case build
            set -g has_build 1
    end
end

function mark_lint_task
    switch "$argv[1]"
        case lint:large-files
            set -g has_large_files 1
        case lint:complexity
            set -g has_complexity 1
        case lint:dead-code
            set -g has_dead_code 1
        case lint:flog
            set -g has_flog 1
        case lint:flay
            set -g has_flay 1
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
