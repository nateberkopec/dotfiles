# Reduce Homebrew usage

## Status

Accepted

## Context

Homebrew adds dependence on another package manager and, for taps and casks, can add third-party packaging between this repository and the software's official distribution. Removing it can also introduce a new binary builder to trust, slow down CI and local updates, or leave this repository maintaining a custom build recipe. The installation manager and the binary publisher are separate choices: using mise does not by itself reduce the trust placed in a distributor. Direct application distribution can require additional lifecycle integration, so migration must preserve the behavior that `dotf` currently provides.

## Decision

Reduce Homebrew use where a replacement improves the overall trade-off between trust, installation and update speed, and maintenance. Eliminating Homebrew is a preference, not a requirement at any cost. Do not add new third-party Homebrew taps.

Prefer package sources in this order:

1. Publisher-provided binaries, managed by mise where practical. Aqua or an official upstream release backend can provide installation metadata without introducing another binary builder.
2. An existing trusted distributor when upstream does not provide suitable binaries. Retaining an existing Homebrew package is acceptable when the alternatives add a new binary builder to trust or require substantial custom installation code. Do not introduce another distributor solely to remove a Homebrew dependency or move a tool into mise.
3. Custom source builds only for a compelling reason that justifies their build time and maintenance. Removing one more Homebrew package is not sufficient by itself.

For example, keep the existing Homebrew GnuPG package rather than maintain macOS-specific source-build workarounds or add a new binary distributor solely to replace it.

Existing Homebrew dependencies remain until a replacement preserves necessary functionality, architecture and platform support, artifact verification, idempotent installation and updates, and user data. Do not silently drop an application when no suitable alternative exists. This direction does not require immediate elimination of every Homebrew formula.

This decision supersedes only the Homebrew fallback portions of [ADR 0002](0002-prefer-mise-as-tool-owner.md) and [ADR 0007](0007-separate-convergence-from-dependency-updates.md). Their convergence and update-separation decisions remain in effect, as does ADR 0007's cask behavior while casks remain during the transition.
