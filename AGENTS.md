# AGENTS.md

These are my dotfiles. See README.md. For high-level project intent, see docs/repo-intent.md.

I make changes to this repository exclusively through GitHub pull requests. Pushing to main directly is disabled.

## CI

- CI usually takes about 10 minutes to finish running.
- Do not use `[ci skip]`, `[skip ci]`, or similar commit-message skip markers in this repository. They leave required PR checks without successful statuses, so the PR gets stuck instead of merging.
- Docs-only changes use the repository's explicit skip mechanisms instead:
  - The integration workflow detects changes limited to `docs/*`, `README.md`, or `AGENTS.md` and skips the integration test steps while still reporting successful required checks.
  - Local `hk`/mise hooks use task `sources` to skip unchanged checks before commit. CI lint and unit-test workflows still run on PRs.

Lints enforced on this codebase via `hk`/git hooks:

- `standard`: Runs `standardrb`, including custom cops that prefer `SystemAdapter` over direct filesystem classes and keep Step public methods constrained.
- `complexity`: Runs RuboCop's `Metrics/PerceivedComplexity` using `.rubocop-custom.yml`.
- `large-files`: Checks files for the staged line-addition limit before commit.
- `secrets`: Runs `gitleaks` over the working tree with repo config and redacted output.
- `dead-code`: Runs the custom dead-code checker for unused Ruby methods, honoring `.debride-whitelist`.
- `flog`: Fails if any Ruby method's flog complexity reaches the configured threshold, which is 25 by default.
- `flay`: Fails if Ruby duplication reaches the configured score threshold, which is 10 by default.
- `skills`: Validates Claude skill files under `files/home/.claude/skills`.

The pre-commit hook also runs the full Ruby test suite via `bundle exec rake test`.

## Ruby

Keep files ~100 LOC. Split as needed.

### Testing Principles

- Never test the type or shape of return values. Tests should verify behavior, not implementation details or data structures.
- Each public method should have a test for its default return value with no setup.
- When testing that a method returns the same value as its default, first establish setup that would make it return the opposite without your intervention. Otherwise the test is meaningless.
- Keep variables as close as possible to where they're used. Don't put them in setup or as constants at the top of the test class.
