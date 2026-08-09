# Converge machines with mise bootstrap

## Status

Accepted

## Context

Ruby Steps duplicated capabilities now provided by mise: tool installation, system packages, home-file copying and templating, macOS defaults, and LaunchAgents. Keeping two owners made convergence slower and left unclear sources of truth.

## Decision

`dotf run` converges machines in this order:

1. Bootstrap Homebrew and the official mise binary at `~/.local/bin/mise`.
2. Self-update mise to the newest release published at least three days ago.
3. Run `mise bootstrap`.
4. Run pending one-time migrations.
5. Run imperative Ruby Steps.

Mise owns its own binary independently of Homebrew and APT. A pinned official release bootstraps fresh machines; subsequent runs self-update mise without downgrading installations already ahead of the delayed target.

Mise owns declarative state in `files/home/.config/mise/config.toml`. Ruby Steps remain only where mise cannot express the behavior cleanly.

Bootstrap and convergence code establish the desired state for every machine and must remain safe and useful on every run. A migration performs transition work needed only by machines that used an older dotfiles version, such as removing retired packages, repositories, files, or configuration. Do not put one-time cleanup in bootstrap or a Step merely because it is idempotent; add a versioned migration instead. Fresh machines skip migrations because they have no legacy state to clean up.

Non-admin macOS is the exception for Homebrew packages. Mise cannot target the private `~/.homebrew` prefix, so `InstallBrewCasksStep` installs mise-declared formulae there alongside casks.

## Consequences

- New tools, system packages, home files, defaults, and LaunchAgents belong in mise config.
- Ruby Steps should not duplicate mise-owned state.
- Existing machines use migrations to remove artifacts from retired Steps.
- Integration tests cover admin macOS, non-admin macOS, and Debian convergence.
