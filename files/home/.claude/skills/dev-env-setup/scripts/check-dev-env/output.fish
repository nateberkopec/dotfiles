function check_pass
    set -a passes "$argv[1]"
    if command -q gum
        gum style --foreground 2 "  PASS  $argv[1]"
    else
        echo "  PASS  $argv[1]"
    end
end

function check_fail
    set -a failures "$argv[1]|$argv[2]"
    if command -q gum
        gum style --foreground 1 "  FAIL  $argv[1]"
    else
        echo "  FAIL  $argv[1]"
    end
end

function check_warn
    set -a warnings "$argv[1]|$argv[2]"
    if command -q gum
        gum style --foreground 3 "  WARN  $argv[1]"
    else
        echo "  WARN  $argv[1]"
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
