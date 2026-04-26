function print_summary
    echo ""

    set num_passes (count $passes)
    set num_failures (count $failures)
    set num_warnings (count $warnings)
    set total_checks (math $num_passes + $num_failures + $num_warnings)

    if test $num_failures -eq 0
        print_success_summary $total_checks $num_warnings
        exit 0
    end

    print_failure_summary $num_failures $total_checks $num_warnings
    exit 1
end

function print_success_summary
    set summary "All clear! $argv[1] checks passed ($argv[2] warnings)."
    if command -q gum
        gum style --bold --foreground 2 --border rounded --padding "0 2" "$summary"
    else
        echo "$summary"
    end
    echo ""
end

function print_failure_summary
    set num_failures $argv[1]
    set total_checks $argv[2]
    set num_warnings $argv[3]
    set summary "$num_failures issues found out of $total_checks checks."

    if command -q gum
        gum style --bold --foreground 1 --border rounded --padding "0 2" "$summary"
    else
        echo "$summary"
    end
    echo ""

    print_failure_details
    if test $num_warnings -gt 0
        print_warning_details
    end
    echo ""
end

function print_failure_details
    if command -q gum
        gum style --bold "Next actions:"
    else
        echo "Next actions:"
    end

    for failure in $failures
        set parts (string split "|" -- "$failure")
        echo "  - $parts[1]: $parts[2]"
    end
end

function print_warning_details
    echo ""
    if command -q gum
        gum style --bold "Warnings (may not apply):"
    else
        echo "Warnings (may not apply):"
    end

    for warning in $warnings
        set parts (string split "|" -- "$warning")
        echo "  - $parts[1]: $parts[2]"
    end
end
