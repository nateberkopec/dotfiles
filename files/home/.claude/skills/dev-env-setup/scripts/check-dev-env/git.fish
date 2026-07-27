function check_git_cleanliness
    git -C "$target_dir" rev-parse --is-inside-work-tree >/dev/null 2>/dev/null
    or return

    set status_entries (git -C "$target_dir" status --porcelain=v1 -z 2>/dev/null | string split0)
    set git_status $pipestatus[1]
    if test $git_status -ne 0
        check_fail "git clean (status unavailable)" "Fix repository access or corruption before continuing"
        return
    end
    set dirty_count (count $status_entries)

    if test "$dirty_count" -eq 0
        check_pass "git clean"
    else
        check_fail "git clean ($dirty_count changed paths; names redacted)" "Restore the pre-setup clean baseline or exclude local-only setup files"
    end
end
