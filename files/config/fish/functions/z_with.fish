# Function to combine zoxide with other commands
function z_with
    if test (count $argv) -lt 2
        echo "Usage: z_with <command> <path>"
        return 1
    end

    set -l cmd $argv[1]
    set -l path_arg $argv[2..-1]

    # Check if the path exists directly
    if test -e "$path_arg"
        set path "$path_arg"
    else
        # If not, try to use zoxide to find the path
        set path (zoxide query $path_arg)
    end

    if test -z "$path"
        echo "No matching path found"
        return 1
    end

    eval "$cmd $path"
end

# Completion for z_with
complete -c z_with -f -a "(__fish_complete_command)" -n "test (count (commandline -opc)) -eq 1" -d "Command to run"
complete -c z_with -f -a "(zoxide query -l)" -n "test (count (commandline -opc)) -gt 1" -d "Zoxide path"
