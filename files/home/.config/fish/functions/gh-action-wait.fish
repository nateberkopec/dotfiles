function gh-action-wait --description "Wait for a GitHub Actions run to complete"
    set -l input $argv[1]

    if test (count $argv) -eq 0
        set input (gh pr view --json number --jq '.number' 2>/dev/null)
        if test $status -ne 0
            echo "Error: Could not find PR for current branch"
            echo "Usage: gh-action-wait <run_id|pr_url>"
            return 1
        end
        echo "Watching PR #$input"
    end

    if string match -qr '^https?://' $input
        gh pr checks $input --watch --interval 10
        set -l exit_code $status
        echo -n \a
        return $exit_code
    else
        gh run watch $input --exit-status
        set -l exit_code $status
        echo -n \a
        return $exit_code
    end
end
