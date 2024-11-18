function wait_for_gha_run --description "Wait for a GitHub Actions run to complete"
    # Check if run ID is provided
    if test (count $argv) -eq 0
        echo "Usage: wait_for_gh_run <run_id>"
        return 1
    end

    set -l run_id $argv[1]

    while true
        # Get the status of the run
        set -l run_status (gh run view $run_id --json status -q .status)

        echo "Current status: $run_status"

        # Check if the run has completed
        if test "$run_status" = "completed"
            set -l conclusion (gh run view $run_id --json conclusion -q .conclusion)
            echo "Run completed with conclusion: $conclusion"

            # Return appropriate status based on conclusion
            if test "$conclusion" = "success"
                return 0
            else
                return 1
            end
        end

        # Wait for 30 seconds before checking again
        echo "Waiting 30 seconds before next check..."
        sleep 30
    end
end
