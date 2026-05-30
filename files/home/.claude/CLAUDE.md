# AGENTS.md

## Shell

I use fish. When writing shell scripts intended for the user, use fish. For temporary stuff or stuff for your own use, you can use any shell you like, such as bash or zsh.

Use `gum` to make your shell scripts pretty and fun!

`find` has a 2 second time limit, enforced via an agent harness hook. When using find, set your timeout to 2 seconds or less. Longer timeouts are rejected.

## CI

- CI red: `gh run list/view`, rerun, fix, push, repeat til green.

## Git, Github

Use `gh` cli for all github interactions.

The GH_TOKEN provided cannot open pull requests. Just push the branch (SSH) and open the /new URL for me if I ask for a PR.

GPG sign is on by default, but you should always use --no-gpg-sign unless otherwise instructed.

Safe by default: `git status/diff/log`. Push only when user asks.

Destructive ops forbidden unless explicit (`reset --hard`, `clean`, `restore`, `rm`, …).

For commits which only change markdown or docs, with no code changes, add `[ci skip]` to the commit message. Check first re workflows if CI must run in order for the PR to be mergable.

GitHub CLI for PRs/CI/releases. Given issue/PR URL (or `/pull/5`): use `gh`, not web search.

Examples: `gh issue view <url> --comments -R owner/repo`, `gh pr view <url> --comments --files -R owner/repo`.

## Code Changes

Avoid diff noise from purely stylistic changes (e.g., `'` vs `"`, misc blank lines). Let linters handle style automatically.

Use boolean expressions with implicit return for predicate methods, not guard clauses or case statements with literal true/false.

## Dotfiles Migrations

Use dotf migrations for one-time changes needed on machines that have already run `dotf run`, especially cleanup or state changes that a fresh setup would not need. Examples: uninstalling packages moved from Homebrew to mise, untapping obsolete taps, deleting old files, or migrating local state.

Do not add migrations for normal desired-state setup. If a fresh machine should get something, encode it in config/steps; migrations only bring existing machines closer to that fresh-machine state.

Migrations live in `lib/dotfiles/migrations/`, have monotonically increasing timestamp-like versions, and define `up`/`down` methods. They can use the same helpers as steps. Keep them idempotent and safe to rerun where practical. Do not write tests for individual migrations.

## Important Locations on My System

My dotfiles in live ~/.dotfiles. See the README.md there for info on how they work.

My "inbox" is in ~/Documents/Inbox. Screenshots go there by default.

Rather than dirty up the present working directory, I like to put "temporary" work files in ./tmp if it exists or /tmp if it does not.

When I ask questions about how dependencies work, read the source code. Clone/download the dependency to /tmp, or use `bundle open` or equivalent.

## qmd

I keep useful information in qmd. This useful information is stored in "document collections".

- Local search/RAG for document collections. Installed via mise (`npm:@tobilu/qmd`).
- Important collections to know:
  - `ruby` - consult this collection when doing complex tasks with Ruby, such as refactoring, planning a feature.
  - `ruby-perf` - consult this collection when doing complex tasks with Ruby performance.
- Usage: `qmd --help`.
- **Never commit collection contents to git.** Collections contain user documents and must remain local-only.
