# Completions for rake (Ruby Make)

function __fish_rake_tasks
    rake -AT 2>/dev/null | string replace -r '^rake (\S+)\s+# (.*)' '$1\t$2'
end

complete -c rake -f
complete -c rake -a '(__fish_rake_tasks)'
complete -c rake -l all -s A -d "Show all tasks, even uncommented ones"
complete -c rake -l backtrace -d "Enable full backtrace"
complete -c rake -l build-all -s B -d "Build all prerequisites"
complete -c rake -l comments -d "Show commented tasks only"
complete -c rake -l describe -s D -d "Describe tasks matching PATTERN"
complete -c rake -l directory -s C -r -a '(__fish_complete_directories)' -d "Change to DIRECTORY"
complete -c rake -l dry-run -s n -d "Do a dry run"
complete -c rake -l execute -s e -r -d "Execute Ruby code and exit"
complete -c rake -l execute-continue -s E -r -d "Execute Ruby code, then continue"
complete -c rake -l execute-print -s p -r -d "Execute Ruby code, print result, exit"
complete -c rake -l help -s h -d "Display help message"
complete -c rake -l job-stats -d "Display job statistics"
complete -c rake -l jobs -s j -r -d "Max parallel tasks"
complete -c rake -l libdir -s I -r -a '(__fish_complete_directories)' -d "Include LIBDIR in search path"
complete -c rake -l multitask -s m -d "Treat all tasks as multitasks"
complete -c rake -l no-deprecation-warnings -s X -d "Disable deprecation warnings"
complete -c rake -l no-search -s N -d "Do not search parent directories"
complete -c rake -l no-system -s G -d "Ignore system wide rakefiles"
complete -c rake -l prereqs -s P -d "Display tasks and dependencies"
complete -c rake -l quiet -s q -d "Do not log messages to stdout"
complete -c rake -l rakefile -s f -r -F -d "Use FILENAME as the rakefile"
complete -c rake -l rakelibdir -s R -r -a '(__fish_complete_directories)' -d "Auto-import .rake files in RAKELIBDIR"
complete -c rake -l require -s r -r -d "Require MODULE before executing"
complete -c rake -l rules -d "Trace rules resolution"
complete -c rake -l silent -s s -d "Like --quiet, suppress announcements"
complete -c rake -l suppress-backtrace -r -d "Suppress backtrace matching PATTERN"
complete -c rake -l system -s g -d "Use system wide rakefiles"
complete -c rake -l tasks -s T -d "Display tasks with descriptions"
complete -c rake -l trace -s t -d "Turn on invoke/execute tracing"
complete -c rake -l verbose -s v -d "Log message to stdout"
complete -c rake -l version -s V -d "Display program version"
complete -c rake -l where -s W -d "Describe tasks matching PATTERN"
