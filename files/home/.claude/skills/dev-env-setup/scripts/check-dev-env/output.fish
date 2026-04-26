function record_check
    set bucket $argv[1]
    set color $argv[2]
    set status_label $argv[3]
    set label $argv[4]
    set detail $argv[5]

    if test -n "$detail"
        set -a $bucket "$label|$detail"
    else
        set -a $bucket "$label"
    end

    if command -q gum
        gum style --foreground $color "  $status_label  $label"
    else
        echo "  $status_label  $label"
    end
end

function check_pass
    record_check passes 2 PASS "$argv[1]"
end

function check_fail
    record_check failures 1 FAIL "$argv[1]" "$argv[2]"
end

function check_warn
    record_check warnings 3 WARN "$argv[1]" "$argv[2]"
end

function report_flag
    set variable_name $argv[1]
    set label $argv[2]
    set miss_function $argv[3]
    set message $argv[4]

    if test $$variable_name -eq 1
        check_pass "$label"
    else
        $miss_function "$label" "$message"
    end
end

function print_header
    echo ""
    if command -q gum
        gum style --bold --border double --padding "0 2" "Dev Environment Audit: $target_dir"
    else
        echo "=== Dev Environment Audit: $target_dir ==="
    end
    echo ""
end
