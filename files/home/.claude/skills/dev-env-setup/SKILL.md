---
name: dev-env-setup
description: Set up or audit Nate's standard dev environment in a project directory. Use for mise tasks, hk hooks, CI hardening, or standardized project tooling.
---

# Standard dev environment

Run the installed checker first:

```fish
fish ~/.claude/skills/dev-env-setup/scripts/check-dev-env.fish /path/to/project
```

Treat its failures as the worklist. Run it again after setup; completion requires every applicable check to pass.

## Safety and ownership

Determine ownership with `git shortlog -sn --no-merges | head -5`; ask when unclear. In a repository Nate does not own, local setup must leave the *entire* `git status --porcelain` clean. Require a clean baseline before changing anything, use local config or `.git/info/exclude`, and stop if unrelated preexisting dirt makes that guarantee unverifiable. The checker detects ordinary repositories and linked worktrees and reports dirty path counts without exposing names.

Never read or store plaintext credentials. Use fnox/1Password runtime references and the `env-to-fnox` skill. Keep `.env` untracked and examples fake. GitHub Actions must pin third-party actions to full commit SHAs.

## Choose references

Read only the branch needed:

- For mise and environment configuration, read [references/mise-and-hooks.md](references/mise-and-hooks.md).
- For the standard task set, read [references/standard-tasks.md](references/standard-tasks.md); for aliases, serve behavior, and test runtime, read [references/project-commands.md](references/project-commands.md); for hooks, read [references/hk-hooks.md](references/hk-hooks.md).
- For gitleaks, baselines, secret handling, and GitHub Actions, read [references/security-and-ci.md](references/security-and-ci.md). Baseline generation must use `--redact=75`; confirm the report contains no recovered values before committing it.
- For Ruby dependencies, Standard, complexity, dead-code, flog, flay, and Bundler preparation, read [references/ruby-projects.md](references/ruby-projects.md).

Prefer symlinking reusable checker tools from `~/.claude/skills/dev-env-setup/scripts/` rather than copying them.

## Workflow

1. Establish ownership and a clean Git baseline.
2. Run the checker and inspect the project’s existing toolchain.
3. Load only the applicable references and make the smallest changes that satisfy failures.
4. Run dependency preparation, then every standard task directly.
5. Run the checker again.
6. Confirm `git status` is clean for foreign repositories; for owned repositories, account for every intended tracked change.

Do not declare completion while a checker failure, secret exposure, unpinned action, failing task, or unexplained Git change remains.
