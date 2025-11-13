function worktree_claude
    if test (count $argv) -lt 1
        echo "Usage: worktree_claude <worktree-name> [--continue]"
        return 1
    end

    set worktree_name $argv[1]
    set continue_flag ""

    if test (count $argv) -ge 2; and test "$argv[2]" = "--continue"
        set continue_flag "--continue"
    end

    set git_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo "Error: Not in a git repository"
        return 1
    end

    set worktree_path "$git_root/.worktrees/$worktree_name"

    if test -d "$worktree_path"
        echo "Worktree already exists at $worktree_path"
    else
        git worktree add "$worktree_path" -b "$worktree_name"
        if test $status -ne 0
            echo "Error: Failed to create worktree"
            return 1
        end
        echo "Created worktree at $worktree_path"
    end

    cd "$worktree_path"

    if test -n "$continue_flag"
        claude --dangerously-skip-permissions --continue
    else
        claude --dangerously-skip-permissions
    end
end
