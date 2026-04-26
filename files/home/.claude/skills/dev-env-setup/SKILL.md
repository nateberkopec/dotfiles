---
name: dev-env-setup
description: Set up or audit Nate's standard dev environment in a project directory. Use when the user says "set up my standard dev environment", "set up my dev env", "change to my standard dev approach", "audit dev env", "check dev env", or wants to add mise tasks, hk hooks, or standardize project tooling.
---

# Standard Dev Environment Setup

This skill sets up or audits the standard development environment for a project. Run the compliance checker first to see what's missing, then follow the workflow to bring the project into compliance.

## Standard Dev Environment Approach

When the user asks to "set up my standard dev environment" or "change to my standard dev approach", apply these conventions:

- **All tools are configured via mise.** If Nate owns the repo and it is mostly his, commit the `mise.toml` file and work there. If it is someone else's repo and `mise.toml` does not exist, put the mise config in `mise.local.toml`. Install all development tools through mise.
- **Project commands have mise task frontends.** Use the standard task set when applicable:
  - `test`
  - `serve` or `dev`, using [pitchfork](https://pitchfork.jdx.dev/) when multiple processes are needed
  - `lint`
  - `build`, for artifacts
- **Git hooks are managed with `hk`.** `hk` runs hook steps in parallel, so split checks like lint and test into separate steps instead of combining them in one shell task. Linting and testing should run before every commit.

## Compliance Checker

Run the checker script against the target directory:

```bash
fish scripts/check-dev-env.fish /path/to/project
```

The script is located at: `~/.claude/skills/dev-env-setup/scripts/check-dev-env.fish`

Run it first, then use its output to determine which steps below to execute.

## Shared Skill Tools

The reusable hook tools live in the skill directory. Prefer symlinking those tools into a project instead of copying them. Symlinks keep future skill updates flowing into every project and avoid stale local copies.

```fish
mkdir -p tools
ln -sf ~/.claude/skills/dev-env-setup/scripts/check_large_files.rb tools/check_large_files.rb
ln -sf ~/.claude/skills/dev-env-setup/scripts/check_dead_code.rb tools/check_dead_code.rb
```

Then point mise tasks at the project-local symlink, e.g. `ruby tools/check_large_files.rb`. If a repo cannot use symlinks, call the skill script directly from the mise task rather than copying it.

## Git Cleanliness

**Critical rule:** Dev env files must never dirty `git status` in repos you don't own. None of these setup files should appear as untracked or modified. The compliance checker enforces this.

Strategy by file type:

| File | Own repo | Others' repo |
|------|----------|--------------|
| mise config | `mise.toml` (committed) | `mise.local.toml` (gitignored by mise convention) |
| hk config | `hk.pkl` (committed) | `hk.pkl` + add to `.git/info/exclude` |
| `.env` | Never committed; add to `.gitignore` | Never committed; add to `.git/info/exclude` if needed |
| `.env.example` | Committed | Add to `.git/info/exclude` only if it is purely local |
| Other files | Commit normally | Add to `.git/info/exclude` |

`.git/info/exclude` is a local-only gitignore that is never committed or shared. It is the right place to hide project-specific dev env files that don't have a `.local.` variant.

To determine repo ownership: check `git shortlog -sn --no-merges | head -5`. If the user is the top committer by a wide margin, treat it as their repo. When in doubt, ask.

## Environment Components

### 1. mise Configuration

All dev tools must be managed via mise. Choose the config file based on repo ownership:

- **Your repo** (you are the primary author): use `mise.toml`, commit it.
- **Someone else's repo** (most commits are not yours) and `mise.toml` does not already exist: use `mise.local.toml` (gitignored by mise convention).

If `mise.toml` already exists in someone else's repo, work within it rather than creating `mise.local.toml`.

The config must have a `[tools]` section listing the project's dev dependencies. Inspect the project to determine what tools are needed (language runtimes, linters, formatters, etc.) and add them. Include `cloc` when adding the large-file LOC check.

### 2. Environment Variables

Mise must load local environment variables from `.env` using the appropriate mise TOML syntax:

```toml
[env]
_.file = ".env"
```

Rules:

- `.env` contains local secrets and machine-specific values. It must never be committed.
- Add `.env` to `.gitignore` for repos Nate owns, or `.git/info/exclude` for someone else's repo when needed.
- `.env.example` must exist and should be committed when this is Nate's repo.
- `.env.example` documents required keys only. It must be a strict subset of `.env`: every key in `.env.example` must also exist in the local `.env`, but `.env` may contain extra keys.
- Keep example values empty or obviously fake, e.g. `DATABASE_URL=` or `STRIPE_API_KEY=replace-me`.

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

Example mise tasks section:

```toml
[tasks.test]
description = "Run the test suite"
run = "bundle exec rake test"

[tasks.lint]
description = "Run all lint checks"
depends = ["lint:standard", "lint:large-files", "lint:complexity", "lint:dead-code", "lint:flog", "lint:flay"]

[tasks."lint:standard"]
description = "Run standardrb"
run = "bundle exec standardrb"

[tasks."lint:large-files"]
description = "Check staged files for large files"
run = "ruby tools/check_large_files.rb"

[tasks."lint:complexity"]
description = "Run Ruby complexity checks"
run = "bundle exec rubocop --only Metrics/PerceivedComplexity"

[tasks."lint:dead-code"]
description = "Check for dead Ruby methods"
run = "ruby tools/check_dead_code.rb"

[tasks."lint:flog"]
description = "Run flog complexity checks"
run = "bundle exec rake flog"

[tasks."lint:flay"]
description = "Run flay duplication checks"
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

### 4. Serve URL Logging

If the project has a server, prefer a `serve` mise task. The `serve` task must log the server URL within the last 10 lines of output, for example `http://localhost:4000` or `https://localhost:4000`. This makes it easy for agents and humans to discover the running app URL.

If server startup needs setup logic, put it in a script such as `bin/serve` and keep the URL log near the end of the script output:

```fish
#!/usr/bin/env fish
bundle exec puma -p 4000 &
echo "http://localhost:4000"
wait
```

The checker runs `mise run serve` briefly and fails if the last 10 output lines do not include an HTTP or HTTPS URL.

### 5. Test Runtime

The checker runs `mise run test`, measures elapsed time, and warns when it takes longer than 10 seconds. Tests should still run before commit through the normal hk `test` step.

Acceptable remediations for a slow test task are:

- run tests only for changed files;
- add or use a `test:fast` task that still covers 100% of the app's unit-level coverage;
- keep the warning if neither approach can get the task under 10 seconds.

### 6. Large File Check

Pre-commit must include a large-file LOC check so files do not casually grow past the standard size limit. Add `cloc` as a mise-managed tool:

```toml
[tools]
"github:aldanial/cloc" = "latest"
```

Add a dedicated mise task named `lint:large-files` that checks staged files:

```toml
[tasks."lint:large-files"]
description = "Check staged files for large files"
run = "ruby tools/check_large_files.rb"
```

Use the shared skill tool by symlinking it into the project as `tools/check_large_files.rb`; do not copy it. For Ruby projects, the tool inspects staged changes and uses `cloc` to compare the staged version to `HEAD`. It fails when the changes cause any code file to go from fewer than 100 lines of code to more than 100 lines of code. The failure tells the user: "Don't do this unless absolutely appropriate for the domain. Consider decomposing into multiple files. To override this check, use LARGE_FILES_APPROPRIATE=true." `LARGE_FILES_APPROPRIATE=true` skips the hook.

### 7. Ruby Complexity

For Ruby projects, pre-commit must include a complexity check. If the project supports RuboCop, enabling `RuboCop::Cop::Metrics::PerceivedComplexity` completes this check.

Add a dedicated mise task named `lint:complexity`:

```toml
[tasks."lint:complexity"]
description = "Run Ruby complexity checks"
run = "bundle exec rubocop --only Metrics/PerceivedComplexity"
```

Configuration belongs in the project's existing `.rubocop.yml` / `.rubocop-custom.yml` or a new `.rubocop.yml` if the project does not have one. Start with the lowest practical `Max` that passes the existing code, then ratchet down in separate refactors.

If the project does not support RuboCop, add a small custom linter that checks Ruby perceived complexity and wire it to the same `lint:complexity` mise task. For the first commit, the custom linter only needs to run on changed Ruby files.

### 8. Ruby Dead Code Detection

For Ruby projects, pre-commit must include dead-code detection. Use [debride](https://github.com/seattlerb/debride) and wire it to a dedicated mise task named `lint:dead-code`:

```toml
[tasks."lint:dead-code"]
description = "Check for dead Ruby methods"
run = "ruby tools/check_dead_code.rb"
```

Add `debride` to the project's Ruby dependencies. Because `debride` exits 0 when it reports potentially unused methods, symlink the shared skill wrapper as `tools/check_dead_code.rb`. The wrapper runs `bundle exec debride --json`, parses the `missing` result, and exits 1 when new dead code is reported. Keep intentional false positives in `.debride-whitelist`, with comments explaining broad entries. Start by scanning application directories such as `lib` and `app`; include tests only if the project has a whitelist strategy for test methods.

### 9. Ruby flog/flay

For Ruby projects, pre-commit must include `flog` and `flay` checks using the same pattern as this dotfiles repo.

Add `flog` and `flay` to the project's Ruby dependencies. Define Rake tasks with env-configurable thresholds:

```ruby
FLOG_THRESHOLD = (ENV["FLOG_THRESHOLD"] || 25).to_i
FLAY_THRESHOLD = (ENV["FLAY_THRESHOLD"] || 10).to_i

desc "Run flog"
task :flog do
  flog_output = `bundle exec flog -a lib`
  puts flog_output
  method_scores = flog_output.lines.grep(/^\s+[0-9]+\.[0-9]+:.*#/).reject { |line| line.include?("main#none") }
    .map { |line| line.split.first.to_f }
  max_score = method_scores.max
  if max_score && max_score >= FLOG_THRESHOLD
    abort "flog failed: highest complexity (#{max_score}) exceeds threshold (#{FLOG_THRESHOLD})"
  end
  puts "flog passed (max complexity: #{max_score}, threshold: #{FLOG_THRESHOLD})"
end

desc "Run flay"
task :flay do
  flay_output = `bundle exec flay lib`
  puts flay_output
  flay_score = flay_output[/Total score.*?=\s*(\d+)/, 1]&.to_i
  if flay_score && flay_score >= FLAY_THRESHOLD
    abort "flay failed: duplication score (#{flay_score}) exceeds threshold (#{FLAY_THRESHOLD})"
  end
  puts "flay passed (duplication score: #{flay_score}, threshold: #{FLAY_THRESHOLD})"
end
```

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

### 10. hk Git Hooks

Git hooks are managed with [hk](https://hk.jdx.dev/). Configure them in `hk.pkl` at the project root.

Key rules:
- **Split hooks for parallelism.** hk runs steps in parallel, so separate lint and test into distinct steps rather than combining them into one script.
- **Pre-commit must include lint and test.** These are the minimum gates before every commit.
- **Steps should invoke mise tasks.** Use `mise run <task>` as the check command.
- **Others' repos:** hk has no `.local.` config variant, so add `hk.pkl` to `.git/info/exclude` to keep it out of `git status`.

Template `hk.pkl`:

```pkl
amends "package://github.com/jdx/hk/releases/download/v1.39.0/hk@1.39.0#/Config.pkl"

hooks {
  ["pre-commit"] {
    steps {
      ["lint"] {
        check = "mise run lint:standard"
      }
      ["large-files"] {
        check = "mise run lint:large-files"
      }
      ["complexity"] {
        check = "mise run lint:complexity"
      }
      ["dead-code"] {
        check = "mise run lint:dead-code"
      }
      ["flog"] {
        check = "mise run lint:flog"
      }
      ["flay"] {
        check = "mise run lint:flay"
      }
      ["test"] {
        check = "mise run test"
      }
    }
  }
}
```

After creating `hk.pkl`, ensure hk is in the mise `[tools]` section and run:

```bash
mise run -- hk install
```

Or if there's a `setup` mise task, add `hk install` to it.

### 11. Setup Task

Add a `setup` mise task that bootstraps the project for a new developer:

```toml
[tasks.setup]
description = "Install dependencies and git hooks"
run = """
<package install command, e.g. bundle install, npm install>
hk install
"""
```

## Full Workflow

1. **Audit**: Run the compliance checker to see current state.
2. **Inspect**: Read the project's existing tooling (`package.json`, `Gemfile`, `Makefile`, `Cargo.toml`, etc.) to understand what commands exist.
3. **Determine ownership**: Check `git shortlog -sn --no-merges | head -5` to decide own vs. others' repo.
4. **mise config**: Create or update `mise.toml` (own) / `mise.local.toml` (others') with tools and tasks. Move any task `run` block longer than 10 lines into a separate script.
5. **Environment**: Configure mise to load `.env`, ensure `.env` is ignored, and add `.env.example` as a subset of `.env`.
6. **Serve URL**: For projects with a server, ensure `mise run serve` logs the server URL within the last 10 lines of output.
7. **Test runtime**: Let the checker time `mise run test` and warn when it exceeds 10 seconds.
8. **Large files**: Symlink the shared skill tool, then add a dedicated `lint:large-files` task and pre-commit hook step.
9. **Ruby checks**: For Ruby projects, symlink shared skill tools where available, then add dedicated `lint:complexity`, `lint:dead-code`, `lint:flog`, and `lint:flay` tasks and pre-commit hook steps.
10. **hk config**: Create or update `hk.pkl` with pre-commit hooks. For others' repos, add `hk.pkl` to `.git/info/exclude`.
11. **Install**: Run `hk install` to activate the hooks.
12. **Verify**: Run the compliance checker again to confirm everything passes, including git cleanliness.

