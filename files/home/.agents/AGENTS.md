# AGENTS.md

Follow YAGNI principles.

When deleting code, leave no vestigial traces, whale legs, or references to the old implementation. 

## Shell

I use fish. When writing shell scripts intended for the user, use fish. For temporary stuff or stuff for your own use, you can use any shell you like, such as bash or zsh. If a project we're working already uses bash extensively, don't introduce fish,.

`find` has a 2 second time limit, enforced via an agent harness hook. When using find, set your timeout to 2 seconds or less.

## CI

- CI red: use the gh-agent Executor app on server-1 to inspect runs and job logs, rerun, fix, push, repeat til green.

## Git, Github

Use the `gh-agent` Executor app on server-1 for all GitHub interactions. Given an issue/PR URL (or `/pull/5`), discover and call its GitHub tools through Executor, not `gh` CLI or web search. If it's broken or you need something else, ask user.

Every `gh-agent` write requires `model`: provide the actual writing model's runtime ID (`PI_MODEL` in Pi). Missing, blank, and placeholder model names are rejected. This requirement applies only to `gh-agent`, not other integrations.

GPG sign is on by default, but you should always use --no-gpg-sign unless otherwise instructed.

For commits which only change markdown or docs, with no code changes, add `[ci skip]` to the commit message. Check first re workflows if CI must run in order for the PR to be mergable.

## Code Changes

Avoid diff noise from purely stylistic changes (e.g., `'` vs `"`, misc blank lines). Let linters handle style automatically.

## pi-intercom
Coordinate with other local pi sessions on related codebases. Use `/skill:pi-intercom` for patterns.

**When:** Same codebase (parallel work), reference codebase (consulting patterns), related repos (shared libraries).

**Not when:** Unrelated codebases, unrelated clients, trivial questions, or when you can proceed independently.

**Principle:** Prefer `send` for notifications; `ask` only when blocked waiting for input.

## Important Locations on My System

My dotfiles in live ~/.dotfiles. 

My "inbox" is in ~/Documents/Inbox. Screenshots go there by default.

Rather than dirty up the present working directory, put "temporary" work files in ./tmp if it exists or /tmp if it does not.

When I ask questions about how dependencies work, read the source code. Clone/download the dependency to /tmp, or use `bundle open` or equivalent.


