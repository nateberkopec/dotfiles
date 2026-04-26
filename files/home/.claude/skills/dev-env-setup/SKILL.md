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

## Git Cleanliness

**Critical rule:** Dev env files must never dirty `git status` in repos you don't own. None of these setup files should appear as untracked or modified. The compliance checker enforces this.

Strategy by file type:

| File | Own repo | Others' repo |
|------|----------|--------------|
| mise config | `mise.toml` (committed) | `mise.local.toml` (gitignored by mise convention) |
| hk config | `hk.pkl` (committed) | `hk.pkl` + add to `.git/info/exclude` |
| Other files | Commit normally | Add to `.git/info/exclude` |

`.git/info/exclude` is a local-only gitignore that is never committed or shared. It is the right place to hide project-specific dev env files that don't have a `.local.` variant.

To determine repo ownership: check `git shortlog -sn --no-merges | head -5`. If the user is the top committer by a wide margin, treat it as their repo. When in doubt, ask.

## Environment Components

### 1. mise Configuration

All dev tools must be managed via mise. Choose the config file based on repo ownership:

- **Your repo** (you are the primary author): use `mise.toml`, commit it.
- **Someone else's repo** (most commits are not yours) and `mise.toml` does not already exist: use `mise.local.toml` (gitignored by mise convention).

If `mise.toml` already exists in someone else's repo, work within it rather than creating `mise.local.toml`.

The config must have a `[tools]` section listing the project's dev dependencies. Inspect the project to determine what tools are needed (language runtimes, linters, formatters, etc.) and add them.

### 2. Standard mise Tasks

Define these standard task frontends in the mise config:

| Task | Purpose | Notes |
|------|---------|-------|
| `test` | Run the test suite | Required for all projects with tests |
| `lint` | Run all linters | Required. May use `depends` to fan out to sub-tasks (e.g., `lint:standard`, `lint:flog`) |
| `serve` or `dev` | Start the development server | Required for anything with a server. Use [pitchfork](https://pitchfork.jdx.dev/) when multiple processes are needed |
| `build` | Build artifacts | Required when the project produces build artifacts |

When the project already has equivalent scripts (e.g., `npm run test`, `bundle exec rake test`, `cargo test`), wrap them as mise tasks rather than replacing them. The mise task is the universal frontend.

Example mise tasks section:

```toml
[tasks.test]
description = "Run the test suite"
run = "bundle exec rake test"

[tasks.lint]
description = "Run all lint checks"
depends = ["lint:standard", "lint:large-files", "lint:complexity", "lint:flog"]

[tasks."lint:standard"]
description = "Run standardrb"
run = "bundle exec standardrb"

[tasks."lint:large-files"]
description = "Check staged files for large files"
run = "ruby tools/check_large_files.rb"

[tasks."lint:complexity"]
description = "Run Ruby complexity checks"
run = "bundle exec rubocop --only Metrics/PerceivedComplexity"

[tasks.dev]
description = "Start development server"
run = "pitchfork start"

[tasks.build]
description = "Build release artifacts"
run = "cargo build --release"
```

Discover what the project actually uses for testing, linting, building, and serving before writing these. Read `package.json`, `Gemfile`, `Cargo.toml`, `Makefile`, etc. to find existing commands.

### 3. Large File Check

Pre-commit must include a large-file check so oversized artifacts do not accidentally enter the repository. Add a dedicated mise task named `lint:large-files` that checks staged files:

```toml
[tasks."lint:large-files"]
description = "Check staged files for large files"
run = "ruby tools/check_large_files.rb"
```

Use a small project script in the appropriate stack. For Ruby projects, `tools/check_large_files.rb` should inspect `git diff --cached --name-only --diff-filter=ACMR` and fail when any staged blob exceeds the project limit. Default to 1 MiB unless the project needs a different documented threshold. Allow an environment override such as `LARGE_FILE_LIMIT_BYTES` when the threshold must be adjusted intentionally.

### 4. Ruby Complexity

For Ruby projects, pre-commit must include a complexity check. If the project supports RuboCop, enabling `RuboCop::Cop::Metrics::PerceivedComplexity` completes this check.

Add a dedicated mise task named `lint:complexity`:

```toml
[tasks."lint:complexity"]
description = "Run Ruby complexity checks"
run = "bundle exec rubocop --only Metrics/PerceivedComplexity"
```

Configuration belongs in the project's existing `.rubocop.yml` / `.rubocop-custom.yml` or a new `.rubocop.yml` if the project does not have one. Start with the lowest practical `Max` that passes the existing code, then ratchet down in separate refactors.

If the project does not support RuboCop, add a small custom linter that checks Ruby perceived complexity and wire it to the same `lint:complexity` mise task. For the first commit, the custom linter only needs to run on changed Ruby files.

### 5. hk Git Hooks

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

### 6. Setup Task

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
4. **mise config**: Create or update `mise.toml` (own) / `mise.local.toml` (others') with tools and tasks.
5. **Large files**: Add a dedicated `lint:large-files` task and pre-commit hook step.
6. **Ruby checks**: For Ruby projects, add a dedicated `lint:complexity` task and pre-commit hook step.
7. **hk config**: Create or update `hk.pkl` with pre-commit hooks. For others' repos, add `hk.pkl` to `.git/info/exclude`.
8. **Install**: Run `hk install` to activate the hooks.
9. **Verify**: Run the compliance checker again to confirm everything passes, including git cleanliness.
