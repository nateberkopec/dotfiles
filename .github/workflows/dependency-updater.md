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

runs-on: ubuntu-22.04 # Prepared Ruby must also run against the agent image libc.

engine:
  id: codex
  args: [-c, 'model_reasoning_effort="low"']
model: gpt-5.6-sol
max-ai-credits: 200
timeout-minutes: 45

steps:
  - name: Resolve the active batch
    env:
      GH_TOKEN: ${{ github.token }}
      BENCHMARK: ${{ inputs.benchmark }}
      PR_NUMBER: ${{ github.event.workflow_run.pull_requests[0].number }}
      ISSUE_NUMBER: ${{ github.event.issue.number }}
      EVENT_HEAD: ${{ github.event.workflow_run.head_sha }}
    run: |
      mkdir -p /tmp/gh-aw/agent
      ruby tools/ci/dependency_context.rb
  - name: Set up Ruby
    uses: ruby/setup-ruby@4c56a21280b36d862b5fc31348f463d60bdc55d5 # v1.301.0
    with:
      ruby-version: 'ruby'
      bundler-cache: true
  - name: Install mise
    uses: jdx/mise-action@1648a7812b9aeae629881980618f079932869151 # v4.0.1
    with:
      install: false
      cache: true
      experimental: true
  - name: Prepare reusable evidence and capabilities
    id: evidence
    env:
      GITHUB_TOKEN: ${{ github.token }}
    run: |
      as_of=""
      if [ "${{ inputs.benchmark }}" = true ]; then as_of=2026-09-06T18:11:29Z; fi
      bundle exec ruby tools/ci/dependency_candidates.rb /tmp/gh-aw/agent/dependency-candidates.json "$(jq -r .base /tmp/gh-aw/agent/pr-context.json)" "$as_of"
      bundle exec ruby tools/ci/dependency_release_notes.rb /tmp/gh-aw/agent/dependency-candidates.json /tmp/gh-aw/agent/release-notes.json
      cp .github/dependency-updater.md /tmp/gh-aw/agent/mission.md
      mkdir -p /tmp/gh-aw/agent/checks
      cp -R tools/ci/dependency_factory tools/ci/dependency_factory.rb tools/ci/check_dependency*.rb /tmp/gh-aw/agent/checks/
      mkdir -p /tmp/gh-aw/agent/checks/runtime-lib
      cp -L /usr/lib/x86_64-linux-gnu/libyaml-0.so.2 /tmp/gh-aw/agent/checks/runtime-lib/
      cp tools/ci/dependency_ruby.sh Gemfile Gemfile.lock /tmp/gh-aw/agent/checks/
      ruby -rrbconfig -e 'puts File.dirname(RbConfig.ruby)' > /tmp/gh-aw/agent/checks/ruby-bin
      printf '%s\n' "$PWD/vendor/bundle" > /tmp/gh-aw/agent/checks/bundle-path
      cd /tmp/gh-aw/agent
      echo "digest=$(cat pr-context.json dependency-candidates.json release-notes.json | sha256sum | cut -d ' ' -f1)" >> "$GITHUB_OUTPUT"

jobs:
  safe_outputs: {if: &validated "needs.agent.result == 'success'"}
  detection: {if: *validated}
  conclusion: {if: *validated}

post-steps:
  - name: Verify immutable evidence, mechanical diff, and publication
    id: validate
    env:
      GH_TOKEN: ${{ github.token }}
      EXPECTED_DIGEST: ${{ steps.evidence.outputs.digest }}
      GIT_NO_REPLACE_OBJECTS: "1"
    run: |
      test "$(cat /tmp/gh-aw/agent/{pr-context,dependency-candidates,release-notes}.json | sha256sum | cut -d ' ' -f1)" = "$EXPECTED_DIGEST"
      git archive "$GITHUB_SHA" tools/ci Gemfile Gemfile.lock | tar -x -C /tmp
      export BUNDLE_GEMFILE=/tmp/Gemfile BUNDLE_PATH="$GITHUB_WORKSPACE/vendor/bundle"
      bundle install
      bundle exec ruby /tmp/tools/ci/check_dependency_output.rb
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
