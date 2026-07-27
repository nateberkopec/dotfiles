### 3. Standard mise Tasks

Define these standard task frontends in the mise config:

| Task | Purpose | Notes |
|------|---------|-------|
| `test` | Run the test suite | Required for all projects with tests |
| `lint` | Run all linters | Required. May use `depends` to fan out to sub-tasks (e.g., `lint:standard`, `lint:flog`) |
| `serve` or `dev` | Start the development server | Required for anything with a server. Use [pitchfork](https://pitchfork.jdx.dev/) when multiple processes are needed |
| `build` | Build artifacts | Required when the project produces build artifacts |

When the project already has equivalent scripts (e.g., `npm run test`, `bundle exec rake test`, `cargo test`), wrap them as mise tasks rather than replacing them. The mise task is the universal frontend.

Keep mise task definitions short. Any task `run` block longer than 10 lines must move into a separate project script in an appropriate location, such as `bin/`, `scripts/`, or a stack-specific scripts directory. The mise task should call that script. The checker fails long task run blocks so shell logic does not accumulate in TOML.

For lint and test tasks, add `sources` so mise can skip unchanged checks during pre-commit. This matters most in mixed Ruby repos where docs, config, or frontend-only commits should not rerun every Ruby lint task. Common Ruby mappings:

| Task | Good `sources` |
|------|----------------|
| `test` | `["**/*.rb", "test/**/*", "lib/**/*"]` |
| `lint:standard` / `lint:rubocop` | `["**/*.rb", ".standard.yml"]` or `["**/*.rb", ".rubocop.yml"]` |
| `lint:complexity` | `["**/*.rb", ".rubocop-custom.yml"]` |
| `lint:dead-code` | `["**/*.rb", "**/*.rake", "bin/*", "Rakefile", ".debride-whitelist", "tools/check_dead_code.rb"]` |
| `lint:flog` / `lint:flay` | `["**/*.rb", "Rakefile"]` |
| `lint:large-files` | `[".git/index"]` so staging changes rerun the check |

Example mise tasks section:

```toml
[tasks.test]
description = "Run the test suite"
sources = ["**/*.rb", "test/**/*", "lib/**/*"]
run = "bundle exec rake test"

[tasks.lint]
description = "Run all lint checks"
depends = ["lint:standard", "lint:large-files", "lint:secrets", "lint:complexity", "lint:dead-code", "lint:flog", "lint:flay"]

[tasks."lint:standard"]
description = "Run standardrb"
sources = ["**/*.rb", ".standard.yml"]
run = "bundle exec standardrb"

[tasks."lint:large-files"]
description = "Check staged files for large files"
sources = [".git/index"]
run = '''git diff --cached --numstat --diff-filter=ACMR | awk -F '\t' '$1 ~ /^[0-9]+$/ && $1 > 100 { print "You are adding more than 100 lines to a file: " $3 " (+" $1 "). This is rarely necessary; consider simplifying the code. Is this the most YAGNI solution? Commit with --no-verify if needed."; bad=1 } END { exit bad }' '''

[tasks."lint:complexity"]
description = "Run Ruby complexity checks"
sources = ["**/*.rb", ".rubocop.yml"]
run = "bundle exec rubocop --only Metrics/PerceivedComplexity"

[tasks."lint:dead-code"]
description = "Check for dead Ruby methods"
sources = ["**/*.rb", "**/*.rake", "bin/*", "Rakefile", ".debride-whitelist", "tools/check_dead_code.rb"]
run = "ruby tools/check_dead_code.rb"

[tasks."lint:flog"]
description = "Run flog complexity checks"
sources = ["**/*.rb", "Rakefile"]
run = "bundle exec rake flog"

[tasks."lint:flay"]
description = "Run flay duplication checks"
sources = ["**/*.rb", "Rakefile"]
run = "bundle exec rake flay"

[tasks.serve]
description = "Start development server"
run = "bin/serve"

[tasks.build]
description = "Build release artifacts"
run = "cargo build --release"
```

If a task needs more than 10 lines, move it out of TOML:

```toml
[tasks."lint:custom"]
description = "Run custom lint checks"
run = "bin/lint-custom"
```

Discover what the project actually uses for testing, linting, building, and serving before writing these. Read `package.json`, `Gemfile`, `Cargo.toml`, `Makefile`, etc. to find existing commands.
