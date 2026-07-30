# Converge machines with mise bootstrap

## Status

Accepted

## Context

Ruby Steps duplicated capabilities now provided by mise: tool installation, system packages, home-file copying and templating, macOS defaults, and LaunchAgents. Keeping two owners made convergence slower and left unclear sources of truth.

## Decision

`dotf run` converges machines in this order:

1. Bootstrap Homebrew and mise.
2. Run `mise bootstrap`.
3. Run pending one-time migrations.
4. Run imperative Ruby Steps.

Mise owns declarative state in `files/home/.config/mise/config.toml`. Ruby Steps remain only where mise cannot express the behavior cleanly.

Non-admin macOS is the exception for Homebrew packages. Mise cannot target the private `~/.homebrew` prefix, so `InstallBrewCasksStep` installs mise-declared formulae there alongside casks.

## Consequences

- New tools, system packages, home files, defaults, and LaunchAgents belong in mise config.
- Ruby Steps should not duplicate mise-owned state.
- Existing machines use migrations to remove artifacts from retired Steps.
- Integration tests cover admin macOS, non-admin macOS, and Debian convergence.
