function set_hk_flag
    set variable_name $argv[1]
    set pattern $argv[2]
    set contents $argv[3..-1]

    if string match -rq "$pattern" -- "$contents"
        set -g $variable_name 1
    end
end

function report_hk_step
    set variable_name $argv[1]
    set label $argv[2]
    set message $argv[3]

    if test $$variable_name -eq 1
        check_pass "$label"
    else
        check_fail "$label" "$message"
    end
end

function check_hk_installed
    if not test -d "$target_dir/.git"
        check_warn "hk hooks installed" "Not a git repository - cannot check hook installation."
        return
    end

    set hooks_path (git -C "$target_dir" config core.hooksPath 2>/dev/null)
    if test -n "$hooks_path"
        check_pass "hk hooks installed (core.hooksPath = $hooks_path)"
    else if test -x "$target_dir/.git/hooks/pre-commit"
        check_precommit_hook_file
    else
        check_fail "hk hooks installed" "Run 'hk install' in the project directory to activate git hooks."
    end
end

function check_precommit_hook_file
    if string match -q '*hk*' -- (cat "$target_dir/.git/hooks/pre-commit" 2>/dev/null)
        check_pass "hk hooks installed"
    else
        check_warn "hk hooks installed" "Run 'hk install' to activate git hooks."
    end
end
