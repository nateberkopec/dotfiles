# Separate convergence from dependency updates

## Status

Accepted

## Context

`dotf run` previously found mise updates while it configured a computer. It also refreshed package-manager data.

As a result, the committed files did not fully define the required state. The command combined computer configuration with dependency review.

Vendors can update GUI applications without Homebrew. Therefore, `dotf` cannot reliably enforce cask versions.

`dotf` does not control the macOS version. The user installs each macOS update when it becomes available.

A new version number is not a sufficient reason for an update. Security changes are always important. Other changes are important only when they give a clear benefit to these workflows.

## Decision

`dotf run` uses only committed state. It does not find or select updates.

The command installs the mise version specified in `config/mise.version`. It runs `mise bootstrap --locked`. It uses the lock file at `files/home/.config/mise/mise.lock`.

A separate dependency factory finds and reviews updates.

Use mise for command-line tools when mise can install them. Use Homebrew for integration formulae and GUI casks that mise cannot install.

`dotf` installs a cask only when the cask is not present. The versions in `config/dependency-updater.yml` are notification baselines. They are not installation targets. `dotf` never downgrades a cask.

The dependency factory does not manage macOS versions. The existing macOS update Step continues to find the latest available update.

A daily GitHub Agentic Workflow keeps a maximum of one unfinished dependency-update pull request. The workflow runs OpenAI Codex and tells it to open a pull request directly.

Codex uses one pull request for all update candidates. For each candidate, Codex reports security information first. Codex then explains the benefit to this repository and its workflows. Codex uses primary sources for this report.

The user makes update decisions with `/dependency-update` comments on the pull request. The Codex workflow removes declined candidates from the pull request and records an explicit wake version in `config/dependency-updater.yml`.

The factory ignores a snooze when a new security advisory appears.

## Consequences

- `dotf run` cannot select an unexpected tool release.
- Pull requests contain all changes to exact pins and native lock files.
- One report contains all dependency notifications for a factory run.
- Application self-updaters do not conflict with cask management.
- The workflows need an OpenAI API key in `OPENAI_API_KEY` or `CODEX_API_KEY`.
- GitHub Agentic Workflows is in public preview.
