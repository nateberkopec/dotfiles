# AGENTS.md

## Shell

I use fish. When writing shell scripts intended for the user, use fish. For temporary stuff or stuff for your own use, you can use any shell you like, such as bash or zsh.

Use `gum` to make your shell scripts pretty and fun! Run `gum` alone to see available options/commands for bling.

## CI

- CI red: `gh run list/view`, rerun, fix, push, repeat til green.

## New Deps

Do a quick health check (recent releases/commits, adoption).

## Git, Github

Use `gh` cli for all github interactions.

GPG sign is on by default, but you should always use --no-gpg-sign unless otherwise instructed.

Safe by default: `git status/diff/log`. Push only when user asks.

Destructive ops forbidden unless explicit (`reset --hard`, `clean`, `restore`, `rm`, …).

Whenever you open a pull request with `gh pr`, leave the description blank.

For commits which only change markdown or docs, with no code changes, add `[ci skip]` to the commit message only when CI is not required for merge.

## Code Changes

Avoid diff noise from purely stylistic changes (e.g., `'` vs `"`). Let linters handle style automatically.

Use boolean expressions with implicit return for predicate methods, not guard clauses or case statements with literal true/false.

## gh
- GitHub CLI for PRs/CI/releases. Given issue/PR URL (or `/pull/5`): use `gh`, not web search.
- Examples: `gh issue view <url> --comments -R owner/repo`, `gh pr view <url> --comments --files -R owner/repo`.

## Important Locations on My System

My dotfiles in live ~/.dotfiles. See the README.md there for info on how they work.

My "inbox" is in ~/Documents/Inbox. Screenshots go there by default.

Rather than dirty up the present working directory, I like to put "temporary" work files in ./tmp if it exists or /tmp if it does not.

## qmd

I keep useful information in qmd. This useful information is stored in "document collections".

- Local search/RAG for document collections. Installed via mise (`npm:@tobilu/qmd`).
- Important collections to know:
  - `ruby` - consult this collection when doing complex tasks with Ruby, such as refactoring, planning a feature.
  - `ruby-perf` - consult this collection when doing complex tasks with Ruby performance.
- Usage: `qmd --help`.
- **Never commit collection contents to git.** Collections contain user documents and must remain local-only.
