function __fish_complete_rake_option --argument-names command condition include_short_flags long short description
    set -l complete_args -c $command -l $long -d $description $argv[7..-1]
    test -n "$condition"; and set complete_args $complete_args -n $condition

    if test "$include_short_flags" = 1; and test -n "$short"
        set complete_args $complete_args -s $short
    end

    complete $complete_args
end

function __fish_register_rake_completions --argument-names command condition include_short_flags
    set -q include_short_flags[1]; or set include_short_flags 1

    set -l complete_args -c $command
    test -n "$condition"; and set complete_args $complete_args -n $condition

    complete $complete_args -f
    complete $complete_args -a '(__fish_rake_tasks)'

    __fish_complete_rake_option $command "$condition" $include_short_flags all A "Show all tasks, even uncommented ones"
    __fish_complete_rake_option $command "$condition" $include_short_flags backtrace '' "Enable full backtrace"
    __fish_complete_rake_option $command "$condition" $include_short_flags build-all B "Build all prerequisites"
    __fish_complete_rake_option $command "$condition" $include_short_flags comments '' "Show commented tasks only"
    __fish_complete_rake_option $command "$condition" $include_short_flags describe D "Describe tasks matching PATTERN"
    __fish_complete_rake_option $command "$condition" $include_short_flags directory C "Change to DIRECTORY" -r -a '(__fish_complete_directories)'
    __fish_complete_rake_option $command "$condition" $include_short_flags dry-run n "Do a dry run"
    __fish_complete_rake_option $command "$condition" $include_short_flags execute e "Execute Ruby code and exit" -r
    __fish_complete_rake_option $command "$condition" $include_short_flags execute-continue E "Execute Ruby code, then continue" -r
    __fish_complete_rake_option $command "$condition" $include_short_flags execute-print p "Execute Ruby code, print result, exit" -r
    __fish_complete_rake_option $command "$condition" $include_short_flags help h "Display help message"
    __fish_complete_rake_option $command "$condition" $include_short_flags job-stats '' "Display job statistics"
    __fish_complete_rake_option $command "$condition" $include_short_flags jobs j "Max parallel tasks" -r
    __fish_complete_rake_option $command "$condition" $include_short_flags libdir I "Include LIBDIR in search path" -r -a '(__fish_complete_directories)'
    __fish_complete_rake_option $command "$condition" $include_short_flags multitask m "Treat all tasks as multitasks"
    __fish_complete_rake_option $command "$condition" $include_short_flags no-deprecation-warnings X "Disable deprecation warnings"
    __fish_complete_rake_option $command "$condition" $include_short_flags no-search N "Do not search parent directories"
    __fish_complete_rake_option $command "$condition" $include_short_flags no-system G "Ignore system wide rakefiles"
    __fish_complete_rake_option $command "$condition" $include_short_flags prereqs P "Display tasks and dependencies"
    __fish_complete_rake_option $command "$condition" $include_short_flags quiet q "Do not log messages to stdout"
    __fish_complete_rake_option $command "$condition" $include_short_flags rakefile f "Use FILENAME as the rakefile" -r -F
    __fish_complete_rake_option $command "$condition" $include_short_flags rakelibdir R "Auto-import .rake files in RAKELIBDIR" -r -a '(__fish_complete_directories)'
    __fish_complete_rake_option $command "$condition" $include_short_flags require r "Require MODULE before executing" -r
    __fish_complete_rake_option $command "$condition" $include_short_flags rules '' "Trace rules resolution"
    __fish_complete_rake_option $command "$condition" $include_short_flags silent s "Like --quiet, suppress announcements"
    __fish_complete_rake_option $command "$condition" $include_short_flags suppress-backtrace '' "Suppress backtrace matching PATTERN" -r
    __fish_complete_rake_option $command "$condition" $include_short_flags system g "Use system wide rakefiles"
    __fish_complete_rake_option $command "$condition" $include_short_flags tasks T "Display tasks with descriptions"
    __fish_complete_rake_option $command "$condition" $include_short_flags trace t "Turn on invoke/execute tracing"
    __fish_complete_rake_option $command "$condition" $include_short_flags verbose v "Log message to stdout"
    __fish_complete_rake_option $command "$condition" $include_short_flags version V "Display program version"
    __fish_complete_rake_option $command "$condition" $include_short_flags where W "Describe tasks matching PATTERN"
end
