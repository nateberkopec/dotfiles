---
name: ruby-flog-flay-setup
description: Install standardized flog/flay Rake tasks and a pre-commit hook that runs bundle exec rake for Ruby projects. Use when adding or normalizing code complexity and duplication checks.
---

# Ruby Flog Flay Setup

## Overview

Install flog/flay Rake tasks with env-configurable thresholds and a pre-commit hook that runs `bundle exec rake`.

## Workflow

### 1) Inspect existing setup

- Check `Gemfile` for `flog` and `flay` entries.
- Search for existing `:flog` or `:flay` rake tasks in `Rakefile` and `rakelib/` to avoid duplicates.
- Check `git config core.hooksPath` to determine the hooks directory (default is `.git/hooks` when unset).

### 2) Ensure dependencies

- Add `gem "flay"` and `gem "flog"` to `Gemfile` if missing (no version pinning).
- Run `bundle install` if needed.

### 3) Define tasks in `Rakefile`

- Define `:flog` and `:flay` tasks directly in `Rakefile`.
- Use env-configurable thresholds with defaults.
- Use `bundle exec` for both tools.
- Log only on failure using `puts` and exit non-zero; stay silent on success.
- Do not filter out any files or paths.
- Allow flay duplication when `Total score <= FLAY_THRESHOLD`.

Example task definitions:

```ruby
desc "Run flog"
task :flog do
  output = `bundle exec flog -a lib`
  threshold = (ENV["FLOG_THRESHOLD"] || 25).to_i
  method_scores = []

  output.each_line do |line|
    if line =~ /^\s*(\d+\.\d+):\s+(.+#.+)\s+(.+\.rb)/
      score = $1.to_f
      method_name = $2.strip
      file_path = $3.strip
      method_scores << [score, "#{method_name} #{file_path}"]
    end
  end

  failing_methods = method_scores.select { |score, _| score > threshold }
  if failing_methods.any?
    puts "\nFlog failed: Methods with complexity score > #{threshold}:"
    failing_methods.each { |score, method_name| puts "  #{score}: #{method_name}" }
    exit 1
  end
end

desc "Run flay"
task :flay do
  output = `bundle exec flay lib`
  threshold = (ENV["FLAY_THRESHOLD"] || 0).to_i

  if (match = output.match(/Total score \(lower is better\) = (\d+)/))
    score = match[1].to_i
    if score > threshold
      puts "\nFlay failed: Total duplication score is #{score}, must be <= #{threshold}"
      puts output
      exit 1
    end
  end
end
```

- Remove or update any conflicting `:flog`/`:flay` tasks in `rakelib/` to avoid duplicate definitions.
- Ensure the default task includes `flog` and `flay` if the project expects them to run in CI.

### 4) Install pre-commit hook

- Create or update `pre-commit` in the hooks directory from `core.hooksPath` (or `.git/hooks`).
- Use bash and run `bundle exec rake` unconditionally.
- Exit non-zero if rake fails.

Example hook:

```bash
#!/usr/bin/env bash
bundle exec rake
result=$?
if [ $result -ne 0 ]; then
  echo "bundle exec rake failed. Commit aborted."
  exit $result
fi
```

- Ensure the hook is executable.

### 5) Verify

- Run `bundle exec rake` and confirm it succeeds.
- Make a test commit if needed to confirm the hook blocks failing builds.
