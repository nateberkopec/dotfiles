---
on:
  schedule:
    - cron: "0 18 * * 0" # Monday 03:00 JST
  workflow_dispatch:
    inputs:
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

env: {GH_AW_CODEX_MAX_REBUILD_FACTOR: "60"}

engine:
  id: codex
  args: [-c, 'model_reasoning_effort="low"']
model: gpt-5.6-sol
max-ai-credits: 200
timeout-minutes: 45

steps:
  - name: Prepare the real Ruby bundle
    uses: ruby/setup-ruby@4c56a21280b36d862b5fc31348f463d60bdc55d5
    with:
      ruby-version: 'ruby'
      bundler-cache: true
  - name: Prepare the frozen checker runtime
    run: |
      mkdir -p /tmp/gh-aw/agent/checks
      cp tools/ci/dependency_ruby.sh Gemfile Gemfile.lock /tmp/gh-aw/agent/checks/
      ruby -rrbconfig -e 'puts File.dirname(RbConfig.ruby)' > /tmp/gh-aw/agent/checks/ruby-bin
      printf '%s\n' "$PWD/vendor/bundle" > /tmp/gh-aw/agent/checks/bundle-path
      printf '%s\n' 'abort unless Bundler.default_gemfile.to_s == "/tmp/gh-aw/agent/checks/Gemfile"' 'puts "Pinned Ruby #{RUBY_VERSION} loaded toml-rb despite login-shell and Bundler redirection"' > /tmp/gh-aw/agent/checks/smoke.rb

pre-agent-steps:
  - name: Verify login-shell execution in the actual agent image without network
    run: |
      docker run --rm --network none --user "$(id -u):$(id -g)" --entrypoint /bin/bash \
        -v "$GITHUB_WORKSPACE:$GITHUB_WORKSPACE:ro" -v /opt:/opt:ro -v /tmp/gh-aw:/tmp/gh-aw:ro -w "$GITHUB_WORKSPACE" \
        ghcr.io/github/gh-aw-firewall/agent:0.28.12@sha256:390051be4ed1847f774fd8980b61d3a3523574c0175d00c3fc7cdf2002a88202 \
        -lc 'BUNDLE_GEMFILE=/wrong BUNDLE_APP_CONFIG=/wrong BUNDLE_PATH=/wrong RUBYOPT=-r/wrong sh /tmp/gh-aw/agent/checks/dependency_ruby.sh -rtoml-rb /tmp/gh-aw/agent/checks/smoke.rb'
      mkdir -p "$RUNNER_TEMP/gh-aw/safeoutputs"
      printf '%s\n' '{"type":"noop","message":"Frozen Ruby login-shell regression passed inside the agent image; no model invocation"}' >> "$RUNNER_TEMP/gh-aw/safeoutputs/outputs.jsonl"

jobs:
  safe_outputs: {if: &validated "needs.agent.result == 'success'"}
  detection: {if: *validated}
  conclusion: {if: *validated}

post-steps:
  - name: Require the successful deterministic smoke-test outcome
    id: validate
    run: |
      jq -e '.items[] | select(.type == "noop")' /tmp/gh-aw/agent_output.json
      echo "validated=true" >> "$GITHUB_OUTPUT"
  - name: Require completed validation even when an earlier step was skipped
    if: always()
    env: {VALIDATED: "${{ steps.validate.outputs.validated }}"}
    run: test "$VALIDATED" = true

tools:
  edit:
  bash: [":*"]
  github: {mode: gh-proxy, toolsets: [default, actions]}
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
    branch-prefix: "${{ inputs.benchmark && 'benchmark/' || 'dependency-update-' }}"
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
  add-comment: {target: "*"}
  noop: {report-as-issue: false}
---

Follow `/tmp/gh-aw/agent/mission.md`. Event: `${{ github.event_name }}`; CI run: `${{ github.event.workflow_run.id }}`.
Treat this authorized request as an outcome, not permission to widen writes:

> ${{ inputs.request }}
> ${{ steps.sanitized.outputs.text }}
