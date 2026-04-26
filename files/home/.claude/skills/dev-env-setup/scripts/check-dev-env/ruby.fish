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

    if test $has_complexity -eq 1
        check_pass "mise task: lint:complexity"
    else
        check_fail "mise task: lint:complexity" "Add a [tasks.\"lint:complexity\"] section. For RuboCop projects, run Metrics/PerceivedComplexity; otherwise run a custom changed-file complexity linter."
    end

    if test $has_dead_code -eq 1
        check_pass "mise task: lint:dead-code"
        check_shared_tool_reference check_dead_code.rb
    else
        check_fail "mise task: lint:dead-code" "Add a [tasks.\"lint:dead-code\"] section that runs debride for Ruby projects."
    end

    if test $has_flog -eq 1
        check_pass "mise task: lint:flog"
    else
        check_fail "mise task: lint:flog" "Add a [tasks.\"lint:flog\"] section that runs bundle exec rake flog for Ruby projects."
    end

    if test $has_flay -eq 1
        check_pass "mise task: lint:flay"
    else
        check_fail "mise task: lint:flay" "Add a [tasks.\"lint:flay\"] section that runs bundle exec rake flay for Ruby projects."
    end
end
