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

checkout:
  fetch: ["dependency-update-*"]
  fetch-depth: 0

if: >
  github.event_name != 'workflow_run' ||
  (github.event.workflow_run.conclusion == 'failure' &&
  github.event.workflow_run.event == 'pull_request' &&
  github.event.workflow_run.head_repository.full_name == github.repository &&
  github.event.workflow_run.pull_requests[0].number)

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
timeout-minutes: 60

tools:
  edit:
  bash: [":*"]
  github:
    mode: gh-proxy
    toolsets: [default, actions]
  web-fetch:
  web-search:

network:
  allowed:
    - defaults
    - github
    - go
    - linux-distros
    - node
    - ruby
    - rust
    - acli.atlassian.com
    - api.osv.dev
    - appupdates.agilebits.com
    - blog.rustlang.org
    - cache.agilebits.com
    - cmake.org
    - developer.atlassian.com
    - dl.google.com
    - formulae.brew.sh
    - mise-versions.jdx.dev
    - mise.run
    - support.1password.com
    - tmaproduction.blob.core.windows.net
    - tuf-repo-cdn.sigstore.dev
    - www.ruby-lang.org

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
    allowed-files: &dependency-files
      - .mise.toml
      - Gemfile.lock
      - config/config.yml
      - config/dependency-updater.yml
      - config/mise.version
      - files/home/.config/mise/config.toml
      - files/home/.config/mise/mise.lock
      - files/home/.pi/agent/settings.json
    protected-files: allowed
  push-to-pull-request-branch:
    github-token: ${{ secrets.DEPENDENCY_FACTORY_PAT }}
    target: "${{ github.event.workflow_run.pull_requests[0].number || github.event.issue.number || 'triggering' }}"
    required-labels: [dependency-update]
    fallback-as-pull-request: false
    if-no-changes: ignore
    allowed-files: *dependency-files
    protected-files: allowed
  add-comment:
    required-labels: [dependency-update]
---

# Dependency Software Factory

Keep the run context compact:

- Discover candidates with batched shell commands and filter remote data with `jq` before it reaches context.
- Keep raw responses and logs under `/tmp/gh-aw/agent`. Read excerpts smaller than 20 KB, reuse one evidence file, and fetch each release once and only after it passes the gates.
- Use only `[A-Za-z0-9._-]` in temporary filenames so artifact upload remains valid.
- On a network error, inspect denials with `awk '$8 ~ /TCP_DENIED/ {sub(/:443$/, "", $3); print $3}' /tmp/gh-aw/sandbox/firewall/logs/access.log | sort | uniq -c | sort -nr`. A listed host is blocked for this run; do not retry it.

The triggering event is `${{ github.event_name }}`. The matched slash command is `${{ needs.activation.outputs.slash_command }}`.

If the event is `workflow_run`:

1. Inspect failed run `${{ github.event.workflow_run.id }}` and its job logs.
2. Work only on the associated pull request. Confirm its label and that `${{ github.event.workflow_run.head_sha }}` is still its head.
3. Diagnose the root cause. Push only mechanical pin, lock, or snooze changes allowed by this workflow.
4. If repair requires any other file or behavioral change, remove and snooze the responsible update, regenerate locks, and explain the required manual adaptation in the PR.
5. Run applicable validation and inspect every required check before finishing.

Never ask Nate to review the pull request while a check is pending or failed. A later failed build will invoke this workflow again. Never merge the pull request or create another one.

If the matched slash command is `dependency-update`, handle this command on the triggering dependency-update pull request:

> ${{ steps.sanitized.outputs.text }}

Read `.github/dependency-updater.md` and the complete pull request before acting. Apply the requested batch decisions to the pull request branch, regenerate affected locks, and run the applicable validation. Push all resulting changes to the triggering pull request. Then comment with the decisions applied, your interpretation of any wake boundaries, validation evidence, and any manual action that remains. Never merge the pull request or create another one.

Otherwise, first check for an open pull request with the `dependency-update` label. If one exists, report its URL and make no changes. If none exists, follow `.github/dependency-updater.md` exactly and make all eligible dependency updates in one pull request.
