function detect_ruby_project
    set ruby_project_files (find "$target_dir" -maxdepth 1 -type f \( -name Gemfile -o -name "*.gemspec" -o -name .ruby-version -o -name Rakefile \) 2>/dev/null)
    set -g is_ruby_project 0
    if test (count $ruby_project_files) -gt 0
        set -g is_ruby_project 1
    end
end

function check_ruby_mise_tasks
    if test $is_ruby_project -ne 1
        return
    end

    for spec in \
        'has_complexity|mise task: lint:complexity|Add a [tasks."lint:complexity"] section. For RuboCop projects, run Metrics/PerceivedComplexity; otherwise run a custom changed-file complexity linter.' \
        'has_dead_code|mise task: lint:dead-code|Add a [tasks."lint:dead-code"] section that runs debride for Ruby projects.' \
        'has_flog|mise task: lint:flog|Add a [tasks."lint:flog"] section that runs bundle exec rake flog for Ruby projects.' \
        'has_flay|mise task: lint:flay|Add a [tasks."lint:flay"] section that runs bundle exec rake flay for Ruby projects.'
        set parts (string split "|" -- "$spec")
        report_flag $parts[1] "$parts[2]" check_fail "$parts[3]"
    end

    if test $has_dead_code -eq 1
        check_shared_tool_reference check_dead_code.rb
    end
end
