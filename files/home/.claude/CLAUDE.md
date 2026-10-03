# AGENTS.md

Follow YAGNI principles.

When deleting code, leave no vestigial traces, whale legs, or references to the old implementation. 

## Shell

I use fish. When writing shell scripts intended for the user, use fish. For temporary stuff or stuff for your own use, you can use any shell you like, such as bash or zsh.

Use `gum` to make your shell scripts pretty and fun!

`find` has a 2 second time limit, enforced via an agent harness hook. When using find, set your timeout to 2 seconds or less. Longer timeouts are rejected.

## CI

- CI red: use the gh-agent Executor app on server-1 to inspect runs and job logs, rerun, fix, push, repeat til green.

## Git, Github

Use the `gh-agent` Executor app on server-1 for all GitHub interactions. Given an issue/PR URL (or `/pull/5`), discover and call its GitHub tools through Executor, not `gh` CLI or web search. Use the user's intended PAT-backed profile. Do not switch accounts, broaden token access, or fall back to other GitHub credentials after a permission error. If the app is unavailable or an operation is not exposed, stop and ask the user.

Every write requires `model`: provide the actual writing model's runtime ID (`PI_MODEL` in Pi). Missing, blank, and placeholder model names are rejected. The app generates the AI/model disclosure on nonempty prose bodies, including edits; do not add a disclosure manually. Titles, source contents, and commit messages are not decorated. This changes disclosure, not authorization: existing approval and communication requirements still apply.

Ordinary local Git operations and commit attribution are separate. The current HTTPS Git credential helpers still depend on `gh`; do not log out of it until those helpers are replaced and authenticated Git access is verified.

If there was a relevant github issue for a PR, always reference it in the commit message or PR description (Closes #X).

GPG sign is on by default, but you should always use --no-gpg-sign unless otherwise instructed.

Destructive git ops forbidden unless explicit (`reset --hard`, `clean`, `restore`, `rm`, …).

For commits which only change markdown or docs, with no code changes, add `[ci skip]` to the commit message. Check first re workflows if CI must run in order for the PR to be mergable.

## Code Changes

Avoid diff noise from purely stylistic changes (e.g., `'` vs `"`, misc blank lines). Let linters handle style automatically.

Use boolean expressions with implicit return for predicate methods, not guard clauses or case statements with literal true/false.

## Important Locations on My System

My dotfiles in live ~/.dotfiles. 

My "inbox" is in ~/Documents/Inbox. Screenshots go there by default.

Rather than dirty up the present working directory, put "temporary" work files in ./tmp if it exists or /tmp if it does not.

When I ask questions about how dependencies work, read the source code. Clone/download the dependency to /tmp, or use `bundle open` or equivalent.

