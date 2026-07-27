# Ruby projects
### 9. Ruby Complexity

For Ruby projects, pre-commit must include a complexity check. If the project supports RuboCop, enabling `RuboCop::Cop::Metrics::PerceivedComplexity` completes this check.

Add a dedicated mise task named `lint:complexity`:

```toml
[tasks."lint:complexity"]
description = "Run Ruby complexity checks"
run = "bundle exec rubocop --only Metrics/PerceivedComplexity"
```

Configuration belongs in the project's existing `.rubocop.yml` / `.rubocop-custom.yml` or a new `.rubocop.yml` if the project does not have one. Start with the lowest practical `Max` that passes the existing code, then ratchet down in separate refactors.

If the project does not support RuboCop, add a small custom linter that checks Ruby perceived complexity and wire it to the same `lint:complexity` mise task. For the first commit, the custom linter only needs to run on changed Ruby files.

### 10. Ruby Dead Code Detection

For Ruby projects, pre-commit must include dead-code detection. Use [debride](https://github.com/seattlerb/debride) and wire it to a dedicated mise task named `lint:dead-code`:

```toml
[tasks."lint:dead-code"]
description = "Check for dead Ruby methods"
run = "ruby tools/check_dead_code.rb"
```

Add `debride` to the project's Ruby dependencies. Because `debride` exits 0 when it reports potentially unused methods, symlink the shared skill wrapper as `tools/check_dead_code.rb`. The wrapper runs `bundle exec debride --json`, parses the `missing` result, and exits 1 when new dead code is reported. It scans common application code directories (`app`, `lib`, `tools`, `rubocop`, `rakelib`, `Rakefile`) plus Ruby shebang executables in `bin`, `exe`, `script`, and `scripts` when those paths exist. Keep intentional false positives in `.debride-whitelist`, with comments explaining broad entries. The wrapper also fails on stale whitelist entries, so remove entries as code is deleted or as detection improves. Include tests only if the project has a whitelist strategy for test methods.

### 11. Ruby flog/flay

For Ruby projects, pre-commit must include `flog` and `flay`. Add both development dependencies, then load the `ruby-flog-flay-setup` skill and use its authoritative fail-safe Rake tasks. Keep the explicit project source scope, class- and instance-method parsing, fail-safe output parsing, and fail-at-threshold semantics unchanged. Check flog's command status. For flay, treat a parseable total as authoritative because findings may produce a nonzero status; abort when no total can be parsed.

Expose those tasks through mise:

```toml
[tasks."lint:flog"]
description = "Run flog complexity checks"
run = "bundle exec rake flog"

[tasks."lint:flay"]
description = "Run flay duplication checks"
run = "bundle exec rake flay"
```

Add separate hk pre-commit steps for `lint:flog` and `lint:flay` so hk can run them in parallel with the rest of the pre-commit checks.

### 14. Dependency Preparation

For Ruby projects, prefer `vendor/bundle` plus mise dependency providers over a hand-rolled `setup` task:

```toml
[env]
BUNDLE_PATH = "vendor/bundle"

[deps.bundler]
auto = true

[deps.hk]
sources = ["hk.pkl"]
outputs = [".git/hooks/pre-commit"]
run = "hk install"
```

Run `mise deps` to install stale dependencies. Bundler runs automatically before `mise run` when `auto = true`; the custom hk provider remains explicit unless you also set `auto = true`.
