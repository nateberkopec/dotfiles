# AGENTS.md

These are my dotfiles. See README.md.

I make changes to this repository exclusively through GitHub pull requests. Pushing to main directly is disabled.

## CI

- CI usually takes about 10 minutes to finish running.
- Never use `[ci skip]`, `[skip ci]`, or similar commit-message skip markers in this repository, including for docs-only changes. GitHub skips required workflows entirely.

Lints enforced on this codebase via `hk`, see `hk.pkl`.

## Protected documentation

Do not add, edit, delete, rename, or propose changes to `README.md` or `docs/**` (including ADRs) unless the human explicitly requests them. Otherwise, leave these files alone and continue the requested task without asking permission to change them. When explicitly directed, set `I_HAVE_EXPLICIT_HUMAN_DIRECTION_TO_MODIFY_DOCS=1` only for the individual commit invocation; never persist it or bypass the hook.

## Ruby

Keep files ~100 LOC. Split as needed.
