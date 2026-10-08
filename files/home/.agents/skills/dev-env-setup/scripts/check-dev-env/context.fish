function init_check_context
    set -g target_dir (realpath (string trim -- (test (count $argv) -gt 0; and echo $argv[1]; or echo .)))

    if not test -d "$target_dir"
        echo "Error: $target_dir is not a directory" >&2
        exit 2
    end

    set -g failures
    set -g warnings
    set -g passes
    set -g mise_file ""
    set -g hk_file ""
    set -g is_ruby_project 0
end
