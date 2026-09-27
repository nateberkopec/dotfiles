# AGENTS.md

These are my dotfiles. See README.md.

I make changes to this repository exclusively through GitHub pull requests. Pushing to main directly is disabled.

## CI

- CI usually takes about 10 minutes to finish running.
- Never use `[ci skip]`, `[skip ci]`, or similar commit-message skip markers in this repository, including for docs-only changes. GitHub skips required workflows entirely.

Lints enforced on this codebase via `hk`, see `hk.pkl`.

## Ruby

Keep files ~100 LOC. Split as needed.
