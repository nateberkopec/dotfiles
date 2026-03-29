# Completions for `bundle exec rake`
# Lives in conf.d/ so it loads eagerly — fish only auto-loads completions/rake.fish
# when the command is `rake`, not when it's `bundle`.

function __fish_bundle_exec_rake
    set -l cmd (commandline -xpc)
    test (count $cmd) -ge 3; and test "$cmd[2]" = exec; and test "$cmd[3]" = rake
end

function __fish_rake_tasks
    rake -AT 2>/dev/null | string replace -r '^rake (\S+)\s+# (.*)' '$1\t$2'
end

complete -c bundle -n __fish_bundle_exec_rake -f -a '(__fish_rake_tasks)'
complete -c bundle -n __fish_bundle_exec_rake -l all -d "Show all tasks, even uncommented ones"
complete -c bundle -n __fish_bundle_exec_rake -l backtrace -d "Enable full backtrace"
complete -c bundle -n __fish_bundle_exec_rake -l build-all -d "Build all prerequisites"
complete -c bundle -n __fish_bundle_exec_rake -l comments -d "Show commented tasks only"
complete -c bundle -n __fish_bundle_exec_rake -l describe -d "Describe tasks matching PATTERN"
complete -c bundle -n __fish_bundle_exec_rake -l directory -r -a '(__fish_complete_directories)' -d "Change to DIRECTORY"
complete -c bundle -n __fish_bundle_exec_rake -l dry-run -d "Do a dry run"
complete -c bundle -n __fish_bundle_exec_rake -l execute -r -d "Execute Ruby code and exit"
complete -c bundle -n __fish_bundle_exec_rake -l execute-continue -r -d "Execute Ruby code, then continue"
complete -c bundle -n __fish_bundle_exec_rake -l execute-print -r -d "Execute Ruby code, print result, exit"
complete -c bundle -n __fish_bundle_exec_rake -l help -d "Display help message"
complete -c bundle -n __fish_bundle_exec_rake -l job-stats -d "Display job statistics"
complete -c bundle -n __fish_bundle_exec_rake -l jobs -r -d "Max parallel tasks"
complete -c bundle -n __fish_bundle_exec_rake -l libdir -r -a '(__fish_complete_directories)' -d "Include LIBDIR in search path"
complete -c bundle -n __fish_bundle_exec_rake -l multitask -d "Treat all tasks as multitasks"
complete -c bundle -n __fish_bundle_exec_rake -l no-deprecation-warnings -d "Disable deprecation warnings"
complete -c bundle -n __fish_bundle_exec_rake -l no-search -d "Do not search parent directories"
complete -c bundle -n __fish_bundle_exec_rake -l no-system -d "Ignore system wide rakefiles"
complete -c bundle -n __fish_bundle_exec_rake -l prereqs -d "Display tasks and dependencies"
complete -c bundle -n __fish_bundle_exec_rake -l quiet -d "Do not log messages to stdout"
complete -c bundle -n __fish_bundle_exec_rake -l rakefile -r -d "Use FILENAME as the rakefile"
complete -c bundle -n __fish_bundle_exec_rake -l rakelibdir -r -a '(__fish_complete_directories)' -d "Auto-import .rake files in RAKELIBDIR"
complete -c bundle -n __fish_bundle_exec_rake -l require -r -d "Require MODULE before executing"
complete -c bundle -n __fish_bundle_exec_rake -l rules -d "Trace rules resolution"
complete -c bundle -n __fish_bundle_exec_rake -l silent -d "Like --quiet, suppress announcements"
complete -c bundle -n __fish_bundle_exec_rake -l suppress-backtrace -r -d "Suppress backtrace matching PATTERN"
complete -c bundle -n __fish_bundle_exec_rake -l system -d "Use system wide rakefiles"
complete -c bundle -n __fish_bundle_exec_rake -l tasks -d "Display tasks with descriptions"
complete -c bundle -n __fish_bundle_exec_rake -l trace -d "Turn on invoke/execute tracing"
complete -c bundle -n __fish_bundle_exec_rake -l verbose -d "Log message to stdout"
complete -c bundle -n __fish_bundle_exec_rake -l version -d "Display program version"
complete -c bundle -n __fish_bundle_exec_rake -l where -d "Describe tasks matching PATTERN"
