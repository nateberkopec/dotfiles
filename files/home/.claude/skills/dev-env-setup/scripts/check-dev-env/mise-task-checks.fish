function report_serve_task
    if test $has_serve_or_dev -eq 1
        check_pass "mise task: serve/dev"
    else
        check_warn "mise task: serve/dev" "Add a [tasks.serve] or [tasks.dev] section if this project has a server."
    end

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
    if test $has_build -eq 1
        check_pass "mise task: build"
    else
        check_warn "mise task: build" "Add a [tasks.build] section if this project produces build artifacts."
    end
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
    if test $has_cloc_tool -eq 1
        check_pass "mise tool: cloc"
    else
        check_fail "mise tool: cloc" "Add cloc from GitHub to the mise [tools] section for the large file LOC check: \"github:aldanial/cloc\" = \"latest\""
    end

    if test $has_large_files -eq 1
        check_pass "mise task: lint:large-files"
        check_shared_tool_reference check_large_files.rb
    else
        check_fail "mise task: lint:large-files" "Add a [tasks.\"lint:large-files\"] section that checks staged files crossing the LOC limit."
    end
end
