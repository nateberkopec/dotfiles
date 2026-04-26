function report_serve_task
    report_flag has_serve_or_dev "mise task: serve/dev" check_warn "Add a [tasks.serve] or [tasks.dev] section if this project has a server."

    if test $has_serve_task -eq 1
        check_serve_url
    end
end

function check_serve_url
    if not command -q ruby
        check_fail "serve task logs URL" "Ruby is required to run the serve URL checker."
        return
    end

    set serve_url_output (ruby "$script_dir/check-serve-url.rb" "$target_dir" 2>&1)
    set serve_url_status $status
    if test $serve_url_status -eq 0
        check_pass "serve task logs URL"
    else
        set serve_url_message (string join " " $serve_url_output)
        check_fail "serve task logs URL" "Ensure 'mise run serve' logs a URL like http://localhost:4000 within the last 10 lines of output. $serve_url_message"
    end
end

function report_build_task
    report_flag has_build "mise task: build" check_warn "Add a [tasks.build] section if this project produces build artifacts."
end

function check_long_mise_run_blocks
    if test -z "$mise_file"
        return
    end

    set long_run_blocks (long_mise_task_run_blocks "$mise_file")
    if test (count $long_run_blocks) -eq 0
        check_pass "mise task run blocks <= 10 lines"
        return
    end

    set long_run_tasks
    for block in $long_run_blocks
        set parts (string split "|" -- "$block")
        set -a long_run_tasks "$parts[1] ($parts[2] lines)"
    end
    set long_run_list (string join ", " $long_run_tasks)
    check_fail "mise task run blocks <= 10 lines" "Move long task run blocks to separate scripts, e.g. bin/<task> or scripts/<task>, and have mise call the script: $long_run_list"
end

function check_large_file_tooling
    report_flag has_cloc_tool "mise tool: cloc" check_fail "Add cloc from GitHub to the mise [tools] section for the large file LOC check: \"github:aldanial/cloc\" = \"latest\""
    report_flag has_large_files "mise task: lint:large-files" check_fail "Add a [tasks.\"lint:large-files\"] section that checks staged files crossing the LOC limit."

    if test $has_large_files -eq 1
        check_shared_tool_reference check_large_files.rb
    end
end
