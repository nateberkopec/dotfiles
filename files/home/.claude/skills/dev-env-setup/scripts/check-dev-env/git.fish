function check_git_cleanliness
    if not test -d "$target_dir/.git"
        return
    end

    set dev_env_files mise.local.toml .mise.local.toml hk.pkl hk.toml hk.local.pkl
    set dirty_files (git -C "$target_dir" status --porcelain 2>/dev/null | string replace -r '^.. ' '')
    set dirty_dev_files

    for dirty_file in $dirty_files
        for dev_env_file in $dev_env_files
            if test "$dirty_file" = "$dev_env_file"
                set -a dirty_dev_files "$dirty_file"
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
