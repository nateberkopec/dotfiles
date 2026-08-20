# Separate convergence from dependency updates

## Status

Accepted

## Context

`dotf run` previously selected a delayed mise release and refreshed package-manager metadata while converging a host. Runtime upgrade discovery made committed configuration an incomplete source of truth and mixed machine setup with dependency review.

GUI casks complicate exact convergence because their vendors and built-in updaters own the installed application version. macOS operating-system releases are intentionally always taken when available.

Dependency decisions also need more than a newer version number. Security is always relevant; other changes justify an update only when they provide a concrete benefit to these workflows.

## Decision

`dotf run` consumes committed state only. It installs the exact mise version in `config/mise.version`, runs `mise bootstrap --locked`, and uses the committed multi-platform lock at `files/home/.config/mise/mise.lock`. Upgrade discovery happens outside convergence.

Prefer mise over Homebrew or APT for command-line tools. Homebrew remains for host integration formulae and GUI casks that mise cannot reasonably own.

Self-updating casks are presence-managed. Their versions in `config/dependency-updater.yml` are notification baselines, not installation targets, and `dotf run` never downgrades them. macOS version management is excluded; the existing latest-available update Step remains independent.

A daily GitHub Actions workflow creates at most one open dependency-update issue and assigns it to GitHub Copilot. Copilot opens one batch PR, leads each candidate analysis with security, and answers “what's in it for me?” using primary sources and repository-specific relevance.

Selective decisions happen through `@copilot` comments on that PR. Declined candidates are removed from the batch and recorded with explicit wake versions in `config/dependency-updater.yml`. A security advisory wakes a snooze early.

## Consequences

- Running dotfiles cannot unexpectedly select a new tool release.
- Native locks and exact pins are reviewed in pull requests.
- Dependency notifications are batched rather than emitted per package.
- Casks remain observable without fighting application self-updaters.
- The Copilot assignment workflow requires a user token stored as `COPILOT_ASSIGNMENT_TOKEN` because GitHub's issue-assignment API does not accept the workflow's server token.
