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
  - name: Preserve trusted pre-agent evidence
    uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a
    with:
      name: dependency-evidence
      path: |
        /tmp/gh-aw/agent/pr-context.json
        /tmp/gh-aw/agent/dependency-candidates.json
        /tmp/gh-aw/agent/release-notes.json

jobs:
  safe_outputs: &publication
    needs: [validation]
    if: "needs.agent.result == 'success' && needs.validation.result == 'success' && needs.validation.outputs.validated == 'true'"
  detection: *publication
  conclusion: *publication
  failure_accounting:
    needs: [activation, agent, validation]
    if: "always() && !(needs.agent.result == 'success' && needs.validation.result == 'success' && needs.validation.outputs.validated == 'true')"
    runs-on: ubuntu-latest
    permissions: {actions: read, contents: read, issues: read, pull-requests: read}
    concurrency: {group: gh-aw-conclusion-dependency-updater, cancel-in-progress: false, queue: max}
    steps:
      - uses: github/gh-aw-actions/setup@9271a1804551c0dc4fb0085a97979950aa2f8489
        with: {destination: "${{ runner.temp }}/gh-aw/actions", job-name: conclusion}
      - uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c
        continue-on-error: true
        with: {pattern: "{agent,agent-output-fallback}", merge-multiple: true, path: /tmp/gh-aw}
      - name: Collect original usage without publishing agent output
        if: always()
        run: bash "$RUNNER_TEMP/gh-aw/actions/collect_usage_artifact_files.sh"
      - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a
        if: always()
        with: {name: usage, path: /tmp/gh-aw/usage/, if-no-files-found: ignore}
      - uses: actions/cache/restore@55cc8345863c7cc4c66a329aec7e433d2d1c52a9
        if: always()
        with:
          key: agentic-workflow-usage-dependencyupdater-${{ github.run_id }}
          restore-keys: agentic-workflow-usage-dependencyupdater-
          path: /tmp/gh-aw/agentic-workflow-usage-cache.jsonl
      - name: Record original usage with the pinned daily accounting implementation
        if: always()
        uses: actions/github-script@3a2844b7e9c422d3c10d287c895573f7108da1b3
        with:
          script: |
            const path = require('path');
            const directory = path.join(process.env.RUNNER_TEMP, 'gh-aw/actions');
            require(path.join(directory, 'setup_globals.cjs')).setupGlobals(core, github, context);
            await require(path.join(directory, 'write_daily_aic_usage_cache.cjs')).main();
      - uses: actions/cache/save@55cc8345863c7cc4c66a329aec7e433d2d1c52a9
        if: always()
        with:
          key: agentic-workflow-usage-dependencyupdater-${{ github.run_id }}
          path: /tmp/gh-aw/agentic-workflow-usage-cache.jsonl
      - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a
        if: always()
        with: {name: aic-usage-cache, path: /tmp/gh-aw/agentic-workflow-usage-cache.jsonl, retention-days: 7}
      - name: Summarize publication failure without repository mutation
        if: always()
        run: echo 'Publication did not complete validation. Inspect the agent and validation jobs; original usage was retained without publishing agent output.' >> "$GITHUB_STEP_SUMMARY"
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
        id: validate
        env:
          GH_TOKEN: ${{ github.token }}
          BUNDLE_PATH: ${{ runner.temp }}/validator-bundle
          BUNDLE_IGNORE_CONFIG: "1"
        run: |
          bundle exec ruby tools/ci/validate_dependency_publication.rb /tmp/gh-aw/agent /tmp/dependency-evidence /tmp/publication.sha256
          echo "validated=true" >> "$GITHUB_OUTPUT"
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
    - name: Recheck exact validated publisher input
      run: sha256sum --check /tmp/validated-publication/publication.sha256
    - name: Recheck PR head immediately before mutation
      uses: actions/github-script@3a2844b7e9c422d3c10d287c895573f7108da1b3
      with:
        script: |
          const pr = JSON.parse(require('fs').readFileSync('/tmp/gh-aw/agent/pr-context.json', 'utf8'));
          if (pr.number) {
            const current = (await github.rest.pulls.get({...context.repo, pull_number: pr.number})).data;
            if (current.head.sha !== pr.head) core.setFailed('PR head changed after validation');
          }
          if (pr.benchmark && (await github.rest.git.getRef({...context.repo, ref: 'heads/' + pr.base_branch})).data.object.sha !== pr.base) core.setFailed('Benchmark base changed after validation');
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
    update-branch: false
  add-comment: {target: "*"}
  noop: {report-as-issue: false}
---

Follow `/tmp/gh-aw/agent/mission.md`. Event: `${{ github.event_name }}`; CI run: `${{ github.event.workflow_run.id }}`.
Treat this authorized request as an outcome, not permission to widen writes:

> ${{ inputs.request }}
> ${{ steps.sanitized.outputs.text }}
