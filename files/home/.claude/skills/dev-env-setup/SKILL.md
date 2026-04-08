---
name: dev-env-setup
description: Set up or audit Nate's standard dev environment in a project directory. Use when the user says "set up my standard dev environment", "set up my dev env", "change to my standard dev approach", "audit dev env", "check dev env", or wants to add mise tasks, hk hooks, or standardize project tooling.
---

# Standard Dev Environment Setup

This skill sets up or audits the standard development environment for a project. Run the compliance checker first to see what's missing, then follow the workflow to bring the project into compliance.

## Compliance Checker

Run the checker script against the target directory:

```bash
fish scripts/check-dev-env.fish /path/to/project
```

The script is located at: `~/.claude/skills/dev-env-setup/scripts/check-dev-env.fish`

Run it first, then use its output to determine which steps below to execute.

## Environment Components

### 1. mise Configuration

All dev tools must be managed via mise. Choose the config file based on repo ownership:

- **Your repo** (you are the primary author): use `mise.toml`, commit it.
- **Someone else's repo** (most commits are not yours) and `mise.toml` does not already exist: use `mise.local.toml` (gitignored).

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
depends = ["lint:standard", "lint:flog"]

[tasks."lint:standard"]
description = "Run standardrb"
run = "bundle exec standardrb"

[tasks.dev]
description = "Start development server"
run = "pitchfork start"

[tasks.build]
description = "Build release artifacts"
run = "cargo build --release"
```

Discover what the project actually uses for testing, linting, building, and serving before writing these. Read `package.json`, `Gemfile`, `Cargo.toml`, `Makefile`, etc. to find existing commands.

### 3. hk Git Hooks

Git hooks are managed with [hk](https://hk.jdx.dev/). Configure them in `hk.pkl` at the project root.

Key rules:
- **Split hooks for parallelism.** hk runs steps in parallel, so separate lint and test into distinct steps rather than combining them into one script.
- **Pre-commit must include lint and test.** These are the minimum gates before every commit.
- **Steps should invoke mise tasks.** Use `mise run <task>` as the check command.

Template `hk.pkl`:

```pkl
amends "package://github.com/jdx/hk/releases/download/v1.39.0/hk@1.39.0#/Config.pkl"

hooks {
  ["pre-commit"] {
    steps {
      ["lint"] {
        check = "mise run lint"
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

### 4. Setup Task

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
3. **mise config**: Create or update `mise.toml` / `mise.local.toml` with tools and tasks.
4. **hk config**: Create or update `hk.pkl` with pre-commit hooks.
5. **Install**: Run `hk install` to activate the hooks.
6. **Verify**: Run the compliance checker again to confirm everything passes.
