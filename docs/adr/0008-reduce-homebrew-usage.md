# Reduce Homebrew usage

## Status

Accepted

## Context

Homebrew adds dependence on another package manager and, for taps and casks, can add third-party packaging between this repository and the software's official distribution. Direct application distribution can require additional lifecycle integration, so migration must preserve the behavior that `dotf` currently provides.

## Decision

Actively migrate away from Homebrew, with the goal of eliminating all Homebrew taps and casks and reducing formula use. Prefer packages managed by mise through Aqua, then official upstream GitHub release artifacts. Do not add new third-party Homebrew taps or choose Homebrew merely because it is convenient.

Existing Homebrew dependencies remain until a replacement preserves necessary functionality, architecture and platform support, artifact verification, idempotent installation and updates, and user data. Do not silently drop an application when no suitable alternative exists. This direction does not require immediate elimination of every Homebrew formula.

This decision supersedes only the Homebrew fallback portions of [ADR 0002](0002-prefer-mise-as-tool-owner.md) and [ADR 0007](0007-separate-convergence-from-dependency-updates.md). Their convergence and update-separation decisions remain in effect, as does ADR 0007's cask behavior while casks remain during the transition.
