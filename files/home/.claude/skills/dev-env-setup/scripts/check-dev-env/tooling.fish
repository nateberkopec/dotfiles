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

function check_shared_tool_reference
    set tool_name $argv[1]
    set project_tool "$target_dir/tools/$tool_name"
    set skill_tool "$script_dir/$tool_name"

    if test -L "$project_tool"
        check_shared_tool_symlink "$project_tool" "$skill_tool" "$tool_name"
    else if test -e "$project_tool"
        check_warn "shared tool reference: $tool_name" "tools/$tool_name exists but is not a symlink. Prefer symlinking to $skill_tool instead of copying the tool."
    else if mise_references_skill_tool "$skill_tool"
        check_pass "shared tool reference: $tool_name"
    else
        check_warn "shared tool reference: $tool_name" "Prefer symlinking $skill_tool to tools/$tool_name, or call the skill script directly from the mise task, instead of copying the tool."
    end
end

function check_shared_tool_symlink
    set project_tool $argv[1]
    set skill_tool $argv[2]
    set tool_name $argv[3]

    if test (realpath "$project_tool") = (realpath "$skill_tool")
        check_pass "shared tool reference: $tool_name"
    else
        check_warn "shared tool reference: $tool_name" "Prefer symlinking tools/$tool_name to $skill_tool instead of keeping a separate script."
    end
end

function mise_references_skill_tool
    set skill_tool $argv[1]
    if test -z "$mise_file"
        return 1
    end

    set relative_skill_tool (string replace "$target_dir/" "" "$skill_tool")
    string match -rq "(ruby )?($skill_tool|$relative_skill_tool)" -- (cat "$mise_file")
end
