---
on:
  schedule:
    - cron: "0 18 * * 0" # Monday 03:00 JST
  workflow_dispatch:
  slash_command:
    name: dependency-update
    events: [pull_request_comment]
  roles: [admin]

permissions:
  contents: read
  issues: read
  pull-requests: read

engine: codex

tools:
  edit:
  bash: [":*"]
  web-fetch:
  web-search:

network:
  allowed: [defaults, github, linux-distros, node, ruby]

safe-outputs:
  create-pull-request:
    labels: [dependency-update]
    base-branch: main
    draft: false
    fallback-as-issue: false
    if-no-changes: ignore
    protected-files: allowed
  push-to-pull-request-branch:
    required-labels: [dependency-update]
    if-no-changes: ignore
    protected-files: allowed
  add-comment:
    required-labels: [dependency-update]
---

# Dependency Software Factory

The matched slash command is `${{ needs.activation.outputs.slash_command }}`.

If it is `dependency-update`, handle this command on the triggering dependency-update pull request:

> ${{ steps.sanitized.outputs.text }}

Read `.github/dependency-updater.md` and the complete pull request before acting. Apply the requested batch decisions to the pull request branch, regenerate affected locks, and run the applicable validation. Push all resulting changes to the triggering pull request. Then comment with the decisions applied, your interpretation of any wake boundaries, validation evidence, and any manual action that remains. Never merge the pull request or create another one.

Otherwise, first check for an open pull request with the `dependency-update` label. If one exists, report its URL and make no changes. If none exists, follow `.github/dependency-updater.md` exactly and make all eligible dependency updates in one pull request.
