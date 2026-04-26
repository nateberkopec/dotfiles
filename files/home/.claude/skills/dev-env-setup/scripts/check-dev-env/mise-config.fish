function check_mise_config
    if test -f "$target_dir/mise.toml"
        set -g mise_file "$target_dir/mise.toml"
        check_pass "mise config (mise.toml)"
    else if test -f "$target_dir/mise.local.toml"
        set -g mise_file "$target_dir/mise.local.toml"
        check_pass "mise config (mise.local.toml)"
    else if test -f "$target_dir/.mise.toml"
        set -g mise_file "$target_dir/.mise.toml"
        check_pass "mise config (.mise.toml)"
    else
        check_fail "mise config" "Create mise.toml (your repo) or mise.local.toml (others' repo) with [tools] and [tasks] sections."
    end
end
