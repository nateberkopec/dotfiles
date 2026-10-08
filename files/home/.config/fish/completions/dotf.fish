function __fish_dotf_commands
    if command --query dotf
        command dotf __commands 2>/dev/null
    end
end

function __fish_dotf_command_names
    __fish_dotf_commands | string replace --regex '\t.*$' ''
end

complete --command dotf --erase
complete --command dotf --no-files
complete --command dotf --condition "not __fish_seen_subcommand_from (__fish_dotf_command_names)" --arguments "(__fish_dotf_commands)"
complete --command dotf --short-option h --long-option help --description 'Show this help message'
