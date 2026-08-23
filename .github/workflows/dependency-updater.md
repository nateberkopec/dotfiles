---
on:
  schedule:
    - cron: "0 18 * * 0" # Monday 03:00 JST
  workflow_dispatch:
  workflow_run:
    workflows: [Integration Tests, Lint, Unit Tests]
    types: [completed]
    branches: ["dependency-update-*"]
  slash_command:
    name: dependency-update
    events: [pull_request_comment]
  roles: [admin]

if: github.event_name != 'workflow_run' || github.event.workflow_run.conclusion == 'failure'

concurrency:
  group: dependency-factory-${{ github.event.workflow_run.head_branch || github.event.issue.number || github.run_id }}
  cancel-in-progress: false
  queue: max

permissions:
  actions: read
  contents: read
  issues: read
  pull-requests: read

engine:
  id: codex
  args:
    - -c
    - model_reasoning_effort="max"
# gh-aw-firewall 0.27.44 misresolves model names with query parameters.
model: gpt-5.6-luna

tools:
  edit:
  bash: [":*"]
  github:
    mode: gh-proxy
    toolsets: [default, actions]
  web-fetch:
  web-search:

network:
  allowed: [defaults, github, linux-distros, node, ruby]

safe-outputs:
  threat-detection:
    engine:
      id: codex
      model: gpt-5.6-luna
      # gh-aw 0.86.2 omits the separator before detection args; keep the leading space.
      args:
        - " -c"
        - model_reasoning_effort="max"
  create-pull-request:
    github-token: ${{ secrets.DEPENDENCY_FACTORY_PAT }}
    labels: [dependency-update]
    base-branch: main
    draft: false
    fallback-as-issue: false
    if-no-changes: ignore
    protected-files: allowed
  push-to-pull-request-branch:
    github-token: ${{ secrets.DEPENDENCY_FACTORY_PAT }}
    required-labels: [dependency-update]
    if-no-changes: ignore
    protected-files: allowed
  add-comment:
    required-labels: [dependency-update]
---

# Dependency Software Factory

Keep the run context compact:

- Use deterministic shell commands for candidate discovery. Batch requests and filter every remote response with `jq` before it reaches context.
- Never print full version histories, release objects, asset lists, changelogs, or successful validation logs. Save raw responses and logs under `/tmp/gh-aw/agent`, then read only targeted excerpts smaller than 20 KB.
- Create and reuse one compact evidence file. Never fetch the same release twice. Research release notes only for candidates that pass the pin, age, and snooze gates.

The triggering event is `${{ github.event_name }}`. The matched slash command is `${{ needs.activation.outputs.slash_command }}`.

If the event is `workflow_run`:

1. Inspect failed run `${{ github.event.workflow_run.id }}` and its job logs.
2. Find its associated open pull request. Continue only if it has the `dependency-update` label.
3. Confirm that `${{ github.event.workflow_run.head_sha }}` is still the pull request head. Do nothing if a newer commit has superseded the failure.
4. Diagnose the root cause. Make the smallest complete fix on the same pull request branch.
5. Regenerate affected locks, run the applicable validation, and push the fix.
6. Inspect all required checks before finishing.

Never ask Nate to review the pull request while a check is pending or failed. A later failed build will invoke this workflow again. Never merge the pull request or create another one.

If the matched slash command is `dependency-update`, handle this command on the triggering dependency-update pull request:

> ${{ steps.sanitized.outputs.text }}

Read `.github/dependency-updater.md` and the complete pull request before acting. Apply the requested batch decisions to the pull request branch, regenerate affected locks, and run the applicable validation. Push all resulting changes to the triggering pull request. Then comment with the decisions applied, your interpretation of any wake boundaries, validation evidence, and any manual action that remains. Never merge the pull request or create another one.

Otherwise, first check for an open pull request with the `dependency-update` label. If one exists, report its URL and make no changes. If none exists, follow `.github/dependency-updater.md` exactly and make all eligible dependency updates in one pull request.
