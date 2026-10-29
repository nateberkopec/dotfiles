# AGENTS.md

## Coding

Follow YAGNI principles.

When deleting code, leave no vestigial traces, whale legs, or references to the old implementation.

Never write a new unit test or integration test unless explicitly instructed. You may write new e2e or system level tests.

Never add new code comments.

Rather than dirty up the present working directory, put "temporary" work files in ./tmp if it exists or /tmp if it does not.

When we have questions about how dependencies work, read the source code. Clone/download the dependency to /tmp, or use `bundle open` or equivalent.

For web research, use the `exa` Executor app on server-1 (`web_search_exa`, `web_fetch_exa`).

## Autonomy

Within the task I gave you, keep going: fix, retry, and take the next in-scope step yourself. Work exists only once it is on the remote: commit as you finish each logical unit, staging only files you changed, and push the branch right away. Push to your own branch, not the default branch. Open a PR only when I ask. Start and rerun CI yourself whenever it helps. Ask before other outward-facing actions I haven't requested, such as opening PRs, merging, publishing, deploying, messaging other people, or irreversible deletes.

End any turn that reports on long-running or delegated work with a short status: **Goal**, **Next**, **Needs you** (or "nothing").

## Shell

I use fish. When writing shell scripts intended for the user, use fish. For temporary stuff or stuff for your own use, you can use any shell you like, such as bash or zsh. If a project we're working already uses bash extensively, don't introduce fish.

`find` is capped at a 2 second timeout by an agent harness hook.

The bash tool runs bash. Use fish syntax only inside `fish -c '…'`.

Run commands expected to take more than 2 minutes (builds, test suites, watchers, deploys) in the background with output to a log file, then check back, so I can steer you meanwhile. For GitHub CI, use `executor_watch`.

## Pull Requests

Every time you push a PR, babysit it until there is no automated AI reviewer feedback outstanding and the tests are green. Loop until this is true.

For each piece of AI or human generated feedback:

1. Is this correct? If not, leave a comment and resolve.
2. Is this worthwhile? YAGNI. If it is worthwhile to address, do so, and resolve once you have pushed a commit and left a comment explaining what you did in response.
3. Else, resolve and say why you are ignoring the feedback.

## Git, Github

If the `server-1` MCP is present, you must use `gh-agent` Executor app on server-1 for all GitHub interactions. Given an issue/PR URL (or `/pull/5`), discover and call its GitHub tools through Executor, not `gh` CLI or web search. If it's broken or you need something else, ask user.

Every `gh-agent` write requires `model`: provide the actual writing model's runtime ID (`PI_MODEL` in Pi). Missing, blank, and placeholder model names are rejected. This requirement applies only to `gh-agent`, not other integrations.

GPG sign is on by default, but you should always use --no-gpg-sign unless otherwise instructed.

For commits which only change markdown or docs, with no code changes, add `[ci skip]` to the commit message. Check first re workflows if CI must run in order for the PR to be mergable.

## Nate's Macbook Pro specific instructions.

Only relevant if you are on `Nates-MBP.localdomain`.

### pi-intercom

Coordinate with other local pi sessions on related codebases. Use `/skill:pi-intercom` for patterns.

**When:** Same codebase (parallel work), reference codebase (consulting patterns), related repos (shared libraries).

**Not when:** Unrelated codebases, unrelated clients, trivial questions, or when you can proceed independently.

**Principle:** Prefer `send` for notifications; `ask` only when blocked waiting for input.

### Important Locations on My System

My dotfiles in live ~/.dotfiles.

My "inbox" is in ~/Documents/Inbox. Screenshots go there by default.

I keep code in:

1. ~/Documents/Code.nosync/personal. Personal projects, usually published to Github under nateberkopec.
2. ~/Documents/Code.nosync/business. Stuff for Speedshop, published to speedshop org.
3. ~/Documents/Code.nosync/upstream. Projects I don't own, such as puma or arbitrary OSS I use or work on.
4. ~/Documents/Code.nosync/retainer. Client codebases.


