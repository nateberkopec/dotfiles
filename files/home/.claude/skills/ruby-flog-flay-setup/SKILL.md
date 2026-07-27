---
name: ruby-flog-flay-setup
description: Install standardized flog/flay Rake tasks and pre-commit checks in a Ruby project. Use when adding or normalizing complexity and duplication checks.
---

# Ruby flog/flay setup

Inspect the existing Gemfile, Rakefile, CI, and hooks first. Add `flog` and `flay` to the development/test dependency group and use the project’s normal lockfile workflow.

Add `require "open3"`, thresholds that default to 25 for flog and 10 for flay, and these tasks. Scores **equal to** a threshold fail.

```ruby
FLOG_THRESHOLD = (ENV["FLOG_THRESHOLD"] || 25).to_i
FLAY_THRESHOLD = (ENV["FLAY_THRESHOLD"] || 10).to_i

desc "Run flog"
task :flog do
  output, status = Open3.capture2e("bundle", "exec", "flog", "-a", "lib")
  puts output
  abort "flog failed to run" unless status.success?
  scores = output.lines.filter_map do |line|
    line[/^\s+([0-9]+\.[0-9]+):.*(?:#|::)/, 1]&.to_f unless line.include?("main#none")
  end
  maximum = scores.max || 0.0
  abort "flog failed: #{maximum} reached #{FLOG_THRESHOLD}" if maximum >= FLOG_THRESHOLD
  puts "flog passed (#{maximum} < #{FLOG_THRESHOLD})"
end

desc "Run flay"
task :flay do
  output, = Open3.capture2e("bundle", "exec", "flay", "lib")
  puts output
  score = output[/Total score.*?=\s*(\d+)/, 1]&.to_i
  abort "flay failed: no parseable total score" unless score
  abort "flay failed: #{score} reached #{FLAY_THRESHOLD}" if score >= FLAY_THRESHOLD
  puts "flay passed (#{score} < #{FLAY_THRESHOLD})"
end
```

Scope the commands to maintained project sources (`lib` here); adapt that explicit source root when the project differs. Add both tasks to the default or lint dependency graph and to pre-commit without duplicating existing hooks.

Run each task directly, then the aggregate task. Confirm a class-method score at the threshold fails, malformed tool output fails, a parsed below-threshold score passes, and the hook invokes the aggregate task. Completion requires the lockfile, tasks, and hook configuration to agree.
