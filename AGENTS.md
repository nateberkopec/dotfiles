# AGENTS.md

## Shell

I use fish. When writing shell scripts intended for the user, use fish. For temporary stuff or stuff for your own use, you can use any shell you like, such as bash or zsh.

Use `gum` to make your shell scripts pretty and fun! Run `gum` alone to see available options/commands for bling.

## CI

- CI red: `gh run list/view`, rerun, fix, push, repeat til green.
- CI usually takes about 10 minutes to finish running.

## New Deps

Do a quick health check (recent releases/commits, adoption).

## Git, Github

Use `gh` cli for all github interactions.

GPG sign is on by default, but you should always use --no-gpg-sign unless otherwise instructed.

Safe by default: `git status/diff/log`. Push only when user asks.

Destructive ops forbidden unless explicit (`reset --hard`, `clean`, `restore`, `rm`, …).

Whenever you open a pull request with `gh pr`, leave the description blank.

## Code Changes

Avoid diff noise from purely stylistic changes (e.g., `'` vs `"`). Let linters handle style automatically.

## Critical Thinking
- Fix root cause (not band-aid).
- Unsure: read more code; if still stuck, ask w/ short options.
- Conflicts: call out; pick safer path.
- Unrecognized changes: assume other agent; keep going; focus your changes. If it causes issues, stop + ask user.
- Leave breadcrumb notes in thread.

## Tools

### ast-grep

`ast-grep` is available. Search and Rewrite code at large scale using precise AST patterns. Good for refactor.

### peekaboo
- Screen tools. Cmds: `capture`, `see`, `click`, `list`, `tools`, `permissions status`.
- Use to drive the entire machine: open a browser, interact with windows, etc. Use `peekaboo learn` to understand capabilities.

### gh
- GitHub CLI for PRs/CI/releases. Given issue/PR URL (or `/pull/5`): use `gh`, not web search.
- Examples: `gh issue view <url> --comments -R owner/repo`, `gh pr view <url> --comments --files -R owner/repo`.

### qmd

- Local search/RAG for document collections. Installed via mise (`npm:@tobilu/qmd`).
- Collections defined in `config/config.yml` under `qmd_collections`, stored at `~/Documents/qmd/<name>/`.
- Important collections to know:
  - `ruby` - consult this collection when doing complex tasks with Ruby, such as refactoring, planning a feature, performance optimization.
- Usage: `qmd --help`.
- **Never commit collection contents to git.** Collections contain user documents and must remain local-only.

## Ruby

Keep files ~100 LOC. Split as needed.

### Testing Principles

- Never test the type or shape of return values. Tests should verify behavior, not implementation details or data structures.
- Each public method should have a test for its default return value with no setup.
- When testing that a method returns the same value as its default, first establish setup that would make it return the opposite without your intervention. Otherwise the test is meaningless.
- Keep variables as close as possible to where they're used. Don't put them in setup or as constants at the top of the test class.

### Code Style

- Use boolean expressions with implicit return for predicate methods, not guard clauses or case statements with literal true/false.

## Dotfiles

My dotfiles in live ~/.dotfiles. See the README.md there for info on how they work. Dotfiles are made of "steps".
