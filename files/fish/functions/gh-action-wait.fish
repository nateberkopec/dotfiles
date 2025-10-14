function wait_for_gha_run --description "Wait for a GitHub Actions run to complete"
    if test (count $argv) -eq 0
        echo "Usage: wait_for_gh_run <run_id|pr_url>"
        return 1
    end

    set -l input $argv[1]

    if string match -qr '^https?://' $input
        gh pr checks $input --watch --interval 10
        return $status
    else
        gh run watch $input --exit-status
        return $status
    end
end
