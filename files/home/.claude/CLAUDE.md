# AGENTS.md

## Shell

I use fish. When writing shell scripts intended for the user, use fish. For temporary stuff or stuff for your own use, you can use any shell you like, such as bash or zsh.

Use `gum` to make your shell scripts pretty and fun! Run `gum` alone to see available options/commands for bling.

## Window Management

I use AeroSpace for macOS window management. For window management tasks, prefer AeroSpace commands and configuration.

## CI

- CI red: `gh run list/view`, rerun, fix, push, repeat til green.

## New Deps

When adding new deps, do a quick health check (recent releases/commits, adoption). Andon cord if very old or very little adoption (<5 gh stars, etc).

## Git, Github

Use `gh` cli for all github interactions.

GPG sign is on by default, but you should always use --no-gpg-sign unless otherwise instructed.

Safe by default: `git status/diff/log`. Push only when user asks.

Destructive ops forbidden unless explicit (`reset --hard`, `clean`, `restore`, `rm`, …).

Whenever you open a pull request with `gh pr`, leave the description blank _unless_ you are closing an issue, in which case you should write "Fixes #<ISSUE_NUMBER>".

For commits which only change markdown or docs, with no code changes, add `[ci skip]` to the commit message.

GitHub CLI for PRs/CI/releases. Given issue/PR URL (or `/pull/5`): use `gh`, not web search.

Examples: `gh issue view <url> --comments -R owner/repo`, `gh pr view <url> --comments --files -R owner/repo`.

## Code Changes

Avoid diff noise from purely stylistic changes (e.g., `'` vs `"`, misc blank lines). Let linters handle style automatically.

Use boolean expressions with implicit return for predicate methods, not guard clauses or case statements with literal true/false.

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

## General project setup and structure

I may ask you to "set up my standard dev environment" or "change to my standard dev approach". That means this.

In general, my development environments all have the following structure:

* **All tools configured via mise**. If I own the repo and it's mostly mine, I commit the `mise.toml` file and work in there. If it's someone else's repo (most commits are not mine) and `mise.toml` does not exist, I'll put my mise config in `mise.local.toml`. I install all dev tools this way.
* **Project tasks have frontends as mise task** I like to have the following standard sets of mise tasks:
  * `test`
  * `serve` or `dev`, which may use [pitchfork](https://pitchfork.jdx.dev/) for running multiple processes.
  * `lint`
  * `build`, for artifacts
* **I like git hooks, and manage them with `hk`** This [project](https://hk.jdx.dev/) manages git hooks.
  * `hk` runs hooks in parallel, so rather than have one shell task that combines things, like lint and test, split them out so hk runs them in parallel.
  * I almost always want linting and testing to run before every commit.
