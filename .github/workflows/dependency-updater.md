---
on:
  schedule:
    - cron: "0 18 * * 0" # Monday 03:00 JST
  workflow_dispatch:
    inputs:
      probe:
        description: Negative publication-gate scenario
        type: choice
        default: failed
        options: [failed, skipped, missing]
      request:
        description: Outcome or question for the dependency agent
        type: string
      benchmark:
        description: Replay PR 642 eligibility against its exact baseline
        type: boolean
        default: false
  workflow_run:
    workflows: [Integration Tests, Lint, Unit Tests, Lock Provenance]
    types: [completed]
    branches: ["dependency-update-*"]
  slash_command:
    name: dependency-update
    events: [issues, issue_comment, pull_request_comment]
  roles: [admin]
  status-comment: false
  reaction: none

checkout:
  fetch: ["dependency-update-*", "dependency-benchmark-642", "main"]
  fetch-depth: 0

if: >
  github.event_name != 'workflow_run' ||
  (github.event.workflow_run.event == 'pull_request' &&
  github.event.workflow_run.head_repository.full_name == github.repository &&
  github.event.workflow_run.pull_requests[0].number)

concurrency:
  group: dependency-factory
  cancel-in-progress: false
  queue: max

permissions:
  actions: read
  contents: read
  issues: read
  pull-requests: read

env:
  GH_AW_CODEX_MAX_REBUILD_FACTOR: "60"

engine:
  id: codex
  args: [-c, 'model_reasoning_effort="low"']
model: gpt-5.6-sol
max-ai-credits: 200
timeout-minutes: 45

steps:
  - name: Queue a forbidden comment without invoking the model
    run: |
      mkdir -p /tmp/gh-aw/agent
      printf '%s\n' '{"type":"noop","message":"Deterministic publication gate probe; no model required"}' '{"type":"add_comment","item_number":654,"body":"Gate probe: THIS COMMENT MUST NOT PUBLISH.\n<!-- stripped marker -->\n<details><summary>Decision evidence</summary>\n\n```json dependency-decisions\n{\"outcome\":\"researched\",\"decisions\":[{\"name\":\"npm:@scope/example\"}]}\n```\n</details>"}' >> "$GH_AW_SAFE_OUTPUTS"

jobs:
  safe_outputs:
    if: &validated needs.agent.result == 'success'
  detection:
    if: *validated
  conclusion:
    if: *validated

post-steps:
  - name: Inject failed, skipped, or missing validation and check real sanitization
    id: validate
    if: inputs.probe != 'skipped'
    env:
      PROBE: ${{ inputs.probe }}
    run: |
      node - <<'JS'
      const fs = require('fs');
      const items = JSON.parse(fs.readFileSync('/tmp/gh-aw/agent_output.json', 'utf8')).items;
      const body = items.find(item => item.type === 'add_comment').body;
      if (body.includes('stripped marker') || !body.includes('```json dependency-decisions') || !body.includes('npm:@scope/example')) throw new Error('Serialized sanitizer regression');
      console.log('Actual serialized body retained fenced JSON and stripped HTML comment');
      JS
      test "$PROBE" != failed

  - name: Require completed validation even when an earlier step was skipped
    if: always()
    env:
      VALIDATED: ${{ steps.validate.outputs.validated }}
    run: test "$VALIDATED" = true

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
    - api.osv.dev
    - appupdates.agilebits.com
    - blog.rustlang.org
    - cache.agilebits.com
    - cmake.org
    - dl.google.com
    - formulae.brew.sh
    - mise-versions.jdx.dev
    - mise.run
    - mise.jdx.dev
    - releases.rs
    - unpkg.com
    - support.1password.com
    - tmaproduction.blob.core.windows.net
    - tuf-repo-cdn.sigstore.dev
    - www.ruby-lang.org

safe-outputs:
  threat-detection:
    max-ai-credits: 50
    engine:
      id: codex
      model: gpt-5.6-luna
      # gh-aw 0.86.2 omits the separator before detection args; keep the leading space.
      args: [" -c", 'model_reasoning_effort="high"']
  create-pull-request:
    patch-format: bundle
    github-token: ${{ secrets.DEPENDENCY_FACTORY_PAT }}
    labels: [dependency-update]
    base-branch: "${{ inputs.benchmark && 'dependency-benchmark-642' || 'main' }}"
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
    patch-format: bundle
    github-token: ${{ secrets.DEPENDENCY_FACTORY_PAT }}
    target: "*"
    required-labels: [dependency-update]
    fallback-as-pull-request: false
    if-no-changes: ignore
    allowed-files: *dependency-files
    protected-files: allowed
  update-pull-request:
    target: "*"
    required-labels: [dependency-update]
    title: false
    body: true
  add-comment:
    target: "*"
  noop:
    report-as-issue: false
---

Follow `/tmp/gh-aw/agent/mission.md`. Event: `${{ github.event_name }}`; CI run: `${{ github.event.workflow_run.id }}`.
Treat this authorized request as an outcome, not permission to widen writes:

> ${{ inputs.request }}
> ${{ steps.sanitized.outputs.text }}
