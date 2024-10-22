function gh_client_notes
    # Only run if "client_notes" is in the current directory
    if not string match -q "*client_notes*" $PWD
        set -g gh_status_indicator ""
        return
    end

    # Run the check asynchronously
    fish -c '
    set -l gh_result (gh run list -b main -L 1 --json conclusion -q ".[0].conclusion" 2>/dev/null)
    if test $status -eq 0
        if test "$gh_result" = "failure"
            set -U gh_status_indicator (set_color -b red)(set_color white)" ✘ "(set_color normal)
        else
            set -U gh_status_indicator ""
        end
    else
        set -U gh_status_indicator ""
    end
    kill -WINCH $fish_pid
    ' >/dev/null 2>&1 &

    # Disown the background job to prevent job control messages
    disown
end

function update_prompt_with_gh_status --on-event gh_status_updated
    commandline -f repaint
end