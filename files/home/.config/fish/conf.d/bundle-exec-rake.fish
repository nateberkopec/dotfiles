# Completions for `bundle exec rake`
# Lives in conf.d/ so it loads eagerly — fish only auto-loads completions/rake.fish
# when the command is `rake`, not when it's `bundle`.

function __fish_bundle_exec_rake
    set -l cmd (commandline -xpc)
    test (count $cmd) -ge 3; and test "$cmd[2]" = exec; and test "$cmd[3]" = rake
end

__fish_register_rake_completions bundle __fish_bundle_exec_rake 0
