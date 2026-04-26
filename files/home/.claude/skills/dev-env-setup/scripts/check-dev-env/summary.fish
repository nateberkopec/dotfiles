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
    print_summary_box 2 "All clear! $argv[1] checks passed ($argv[2] warnings)."
end

function print_failure_summary
    set num_failures $argv[1]
    set total_checks $argv[2]
    set num_warnings $argv[3]
    set summary "$num_failures issues found out of $total_checks checks."

    print_summary_box 1 "$summary"

    print_failure_details
    if test $num_warnings -gt 0
        print_warning_details
    end
    echo ""
end

function print_summary_box
    set color $argv[1]
    set summary $argv[2]

    if command -q gum
        gum style --bold --foreground $color --border rounded --padding "0 2" "$summary"
    else
        echo "$summary"
    end
    echo ""
end

function print_failure_details
    print_detail_list "Next actions:" $failures
end

function print_warning_details
    echo ""
    print_detail_list "Warnings (may not apply):" $warnings
end

function print_detail_list
    set heading $argv[1]
    set entries $argv[2..-1]

    if command -q gum
        gum style --bold "$heading"
    else
        echo "$heading"
    end

    for entry in $entries
        set parts (string split "|" -- "$entry")
        echo "  - $parts[1]: $parts[2]"
    end
end
