function check_env_files
    set env_file "$target_dir/.env"
    set env_example_file "$target_dir/.env.example"

    if test -n "$mise_file"; and string match -rq "_.file\\s*=\\s*['\"]\\.env['\"]" -- (cat "$mise_file")
        check_pass "mise loads .env"
    else
        check_fail "mise loads .env" "Add '[env]' with '_.file = \".env\"' to the mise config."
    end

    if test -f "$env_example_file"
        check_pass ".env.example exists"
    else
        check_fail ".env.example exists" "Add a committed .env.example that documents required environment keys."
    end

    check_env_git_status "$env_file"
    check_env_example_subset "$env_file" "$env_example_file"
end

function check_env_git_status
    set env_file $argv[1]
    if not test -d "$target_dir/.git"
        return
    end

    if git -C "$target_dir" ls-files --error-unmatch .env >/dev/null 2>/dev/null
        check_fail ".env not tracked" "Remove .env from git; commit .env.example instead."
    else
        check_pass ".env not tracked"
    end

    set env_status (git -C "$target_dir" status --porcelain -- .env 2>/dev/null)
    if test -z "$env_status"
        check_pass ".env ignored or absent from git status"
    else
        check_fail ".env ignored or absent from git status" "Add .env to .gitignore or .git/info/exclude."
    end
end

function check_env_example_subset
    set env_file $argv[1]
    set env_example_file $argv[2]
    if not test -f "$env_example_file"
        return
    end

    set example_keys (env_file_keys "$env_example_file" | sort -u)
    set env_keys (env_file_keys "$env_file" | sort -u)
    set missing_env_keys

    for key in $example_keys
        if not contains -- "$key" $env_keys
            set -a missing_env_keys "$key"
        end
    end

    if test (count $missing_env_keys) -eq 0
        check_pass ".env.example keys are in .env"
    else
        set missing_list (string join ", " $missing_env_keys)
        check_fail ".env.example keys are in .env" "Add missing keys to local .env or remove them from .env.example: $missing_list"
    end
end
