---
on:
  schedule:
    - cron: "0 18 * * 0" # Monday 03:00 JST
  workflow_dispatch:
    inputs:
      probe_mode:
        description: Deterministic publication boundary case
        type: choice
        options: [poison, failed, skipped, missing, tamper]
        default: poison
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
  - name: Prepare the same Ruby bundle as the agent
    uses: ruby/setup-ruby@4c56a21280b36d862b5fc31348f463d60bdc55d5
    with: {ruby-version: ruby, bundler-cache: true}
  - name: Prepare bounded deterministic evidence
    run: |
      mkdir -p /tmp/gh-aw/agent/checks
      jq -n --arg base "$GITHUB_SHA" '{base:$base,issue:654}' > /tmp/gh-aw/agent/pr-context.json
      printf '%s\n' '{"candidates":[],"generated_at":"2026-09-06T18:11:29Z","minimum_release_age_days":3}' > /tmp/gh-aw/agent/dependency-candidates.json
      printf '%s\n' '{"packages":{}}' > /tmp/gh-aw/agent/release-notes.json
  - name: Preserve trusted pre-agent evidence
    uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a
    with:
      name: dependency-evidence
      path: |
        /tmp/gh-aw/agent/pr-context.json
        /tmp/gh-aw/agent/dependency-candidates.json
        /tmp/gh-aw/agent/release-notes.json

pre-agent-steps:
  - name: Seed real serialized output without inference and poison only agent state
    env: {PROBE_MODE: "${{ inputs.probe_mode }}"}
    run: |
      mkdir -p "$RUNNER_TEMP/gh-aw/safeoutputs"
      bundle exec ruby -rjson -rtoml-rb -e '
        items = [{type: "noop", message: "Deterministic boundary probe; no model invocation"}]
        if %w[failed skipped missing tamper].include?(ENV.fetch("PROBE_MODE"))
          items << {type: "add_comment", item_number: 654, body: "FORBIDDEN publication probe\n<!-- hidden-probe-marker -->\n```json dependency-decisions\n{\"name\":\"npm:@scope/pkg\"}\n```"}
        end
        File.open(ENV.fetch("RUNNER_TEMP") + "/gh-aw/safeoutputs/outputs.jsonl", "a") { |file| items.each { |item| file.puts JSON.generate(item) } }
        if ENV.fetch("PROBE_MODE") == "poison"
          path = Gem.loaded_specs.fetch("toml-rb").full_gem_path + "/lib/toml-rb.rb"
          File.write(path, "abort \"AGENT CACHE POISON\"\n")
          puts "Poisoned agent-only gem: #{path}"
        end'
      if [ "$PROBE_MODE" = poison ]; then
        if bundle exec ruby -rtoml-rb -e nil > /tmp/gh-aw/agent/poison-gem.log 2>&1; then exit 1; fi
        grep 'AGENT CACHE POISON' /tmp/gh-aw/agent/poison-gem.log
        printf '%s\n' 'abort "AGENT CHECKER POISON"' > /tmp/gh-aw/agent/checks/check_dependency_report.rb
        printf '%s\n' 'abort "CANDIDATE GEMFILE POISON"' > Gemfile
        printf '%s\n' '#!/bin/sh' 'echo executed >> /tmp/gh-aw/agent/poison-hook-ran' "printf 'token\\0'" > /tmp/gh-aw/agent/poison-hook
        chmod +x /tmp/gh-aw/agent/poison-hook
        git config core.fsmonitor /tmp/gh-aw/agent/poison-hook
        git status --porcelain
        test -s /tmp/gh-aw/agent/poison-hook-ran
      fi
      if [ "$PROBE_MODE" = failed ]; then printf '%s\n' '{"packages":{"tampered":[]}}' > /tmp/gh-aw/agent/release-notes.json; fi

jobs:
  safe_outputs: &publication
    needs: [validation]
    if: "needs.agent.result == 'success' && needs.validation.result == 'success' && needs.validation.outputs.validated == 'true'"
  detection: *publication
  conclusion: *publication
  validation:
    needs: [agent]
    runs-on: ubuntu-latest
    permissions: {contents: read, actions: read, pull-requests: read}
    outputs: {validated: "${{ steps.validate.outputs.validated }}"}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
        with: {ref: "${{ github.sha }}", fetch-depth: 0, persist-credentials: false}
      - uses: ruby/setup-ruby@4c56a21280b36d862b5fc31348f463d60bdc55d5
        with: {ruby-version: ruby}
      - name: Install trusted validator dependencies without an agent cache
        run: bundle install --jobs 4
        env: {BUNDLE_PATH: "${{ runner.temp }}/validator-bundle", BUNDLE_IGNORE_CONFIG: "1"}
      - uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c
        with: {name: agent, path: /tmp/gh-aw}
      - uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c
        with: {name: dependency-evidence, path: /tmp/dependency-evidence}
      - name: Validate immutable publisher input in private Git metadata
        if: inputs.probe_mode != 'skipped'
        id: validate
        env:
          GH_TOKEN: ${{ github.token }}
          PROBE_MODE: ${{ inputs.probe_mode }}
          BUNDLE_PATH: ${{ runner.temp }}/validator-bundle
          BUNDLE_IGNORE_CONFIG: "1"
        run: |
          if [ "$PROBE_MODE" = poison ]; then sha256sum /tmp/gh-aw/agent/poison-hook-ran > /tmp/poison-hook.sha256; fi
          bundle exec ruby tools/ci/validate_dependency_publication.rb /tmp/gh-aw/agent /tmp/dependency-evidence /tmp/publication.sha256
          if [ "$PROBE_MODE" = poison ]; then sha256sum --check /tmp/poison-hook.sha256; fi
          if [ "$PROBE_MODE" != missing ]; then echo "validated=true" >> "$GITHUB_OUTPUT"; fi
      - name: Require completed validation even if skipped or missing
        if: always()
        env: {VALIDATED: "${{ steps.validate.outputs.validated }}"}
        run: test "$VALIDATED" = true
      - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a
        with: {name: dependency-validation, path: /tmp/publication.sha256}

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
  steps:
    - uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c
      with: {name: dependency-validation, path: /tmp/validated-publication}
    - name: Deliberately tamper after validation to test the final publication binding
      if: inputs.probe_mode == 'tamper'
      run: echo ' ' >> /tmp/gh-aw/agent_output.json
    - name: Recheck exact validated publisher input
      run: sha256sum --check /tmp/validated-publication/publication.sha256
    - name: Recheck PR head immediately before mutation
      uses: actions/github-script@3a2844b7e9c422d3c10d287c895573f7108da1b3
      with:
        script: |
          const pr = JSON.parse(require('fs').readFileSync('/tmp/gh-aw/agent/pr-context.json', 'utf8'));
          if (pr.number && (await github.rest.pulls.get({...context.repo, pull_number: pr.number})).data.head.sha !== pr.head) core.setFailed('PR head changed after validation');
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
