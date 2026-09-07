---
on:
  workflow_dispatch:
checkout: {fetch: ["dependency-update-*", "dependency-benchmark-642"], fetch-depth: 0}
concurrency: {group: dependency-factory, cancel-in-progress: false, queue: max}
permissions: {actions: read, contents: read, issues: read, pull-requests: read}
engine:
  id: codex
  env: {GH_AW_CODEX_CONTEXT_REBUILD_CIRCUIT_BREAKER: "false"}
  args: [-c, 'model_reasoning_effort="high"']
model: gpt-5.6-luna
max-ai-credits: 27
timeout-minutes: 45
steps:
  - uses: ruby/setup-ruby@4c56a21280b36d862b5fc31348f463d60bdc55d5
    with: {ruby-version: ruby, bundler-cache: true}
  - uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c
    with: {name: agent, path: /tmp/v3-prior, github-token: "${{ github.token }}", run-id: 34119289938}
  - uses: jdx/mise-action@1648a7812b9aeae629881980618f079932869151
    with: {install: false, cache: true, experimental: true}
  - name: Inventory the frozen starting state
    env: {GH_TOKEN: "${{ github.token }}"}
    run: |
      mkdir -p /tmp/gh-aw/agent
      test "$(gh api "repos/$GITHUB_REPOSITORY/git/ref/heads/dependency-benchmark-642" --jq .object.sha)" = f5a1dca77a863ed9d5f6c24121b1d9b94026acd2
      cp tools/benchmark-v2/dependency-candidates.json tools/benchmark-v2/source-receipts.json /tmp/gh-aw/agent/
      cp .github/dependency-updater.md /tmp/gh-aw/agent/dependency-mission.md
      printf '%s\n' '{"base":"f5a1dca77a863ed9d5f6c24121b1d9b94026acd2","owner_request":false}' > /tmp/gh-aw/agent/pr-context.json
      git checkout --detach f5a1dca77a863ed9d5f6c24121b1d9b94026acd2
  - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a
    with:
      name: dependency-start
      path: |
        /tmp/gh-aw/agent/pr-context.json
        /tmp/gh-aw/agent/dependency-candidates.json
tools:
  edit:
  bash: [":*"]
  github: {mode: gh-proxy, toolsets: [default, actions]}
  web-fetch:
  web-search:
network:
  allowed: [defaults, github, go, linux-distros, node, ruby, rust, api.osv.dev, appupdates.agilebits.com, blog.rustlang.org, cache.agilebits.com, cmake.org, dl.google.com, formulae.brew.sh, mise-versions.jdx.dev, mise.run, support.1password.com, tmaproduction.blob.core.windows.net, tuf-repo-cdn.sigstore.dev, www.ruby-lang.org]
jobs:
  native:
    needs: [agent, detection]
    permissions: {actions: read, contents: read, pull-requests: read}
    uses: ./.github/workflows/lock-provenance.yml
    with: {factory: true}
  safe_outputs:
    if: "needs.agent.result == 'success' && needs.native.result == 'success'"
safe-outputs:
  needs: [native]
  steps:
    - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
      with: {ref: "${{ github.sha }}", path: trusted-validator, fetch-depth: 0, persist-credentials: false}
    - uses: ruby/setup-ruby@4c56a21280b36d862b5fc31348f463d60bdc55d5
      with: {ruby-version: ruby, working-directory: trusted-validator}
    - uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c
      with: {name: dependency-start, path: /tmp/dependency-start}
    - uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c
      with: {pattern: "native-${{ github.run_attempt }}-*", path: /tmp/native-receipts, merge-multiple: true}
    - name: Validate the exact proposal in the fresh publisher job
      id: dependency_validation
      working-directory: trusted-validator
      env: {GH_TOKEN: "${{ github.token }}", BUNDLE_PATH: "${{ runner.temp }}/validator-bundle", BUNDLE_IGNORE_CONFIG: "1"}
      run: |
        bundle install --jobs 4
        bundle exec ruby tools/ci/validate_dependency_publication.rb /tmp/gh-aw/agent /tmp/dependency-start /tmp/native-receipts
        echo "validated=true" >> "$GITHUB_OUTPUT"
    - name: Require completed validation
      if: always()
      env: {VALIDATED: "${{ steps.dependency_validation.outputs.validated }}"}
      run: test "$VALIDATED" = true
  threat-detection:
    max-ai-credits: 5
    engine:
      id: codex
      model: gpt-5.6-luna
      args: [" -c", 'model_reasoning_effort="high"']
  create-pull-request:
    patch-format: bundle
    github-token: ${{ secrets.DEPENDENCY_FACTORY_PAT }}
    labels: [dependency-update]
    base-branch: dependency-benchmark-642
    draft: true
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
    required-labels: [dependency-update]
---

# Dependency update

Follow `/tmp/gh-aw/agent/dependency-mission.md`. Read `/tmp/gh-aw/agent/pr-context.json` for the frozen starting head. Use compact evidence excerpts and primary sources.

> ${{ steps.sanitized.outputs.text }}

This is the one workflow-owned continuation of frozen V3 run `34119289938`, not a production run. Its unpublished bundle and report are in `/tmp/v3-prior`; recover and improve that work rather than restarting. Create one new draft PR titled `V3 benchmark: ...`, based on `dependency-benchmark-642` at exact commit `f5a1dca77a863ed9d5f6c24121b1d9b94026acd2`. The final `create_pull_request` payload must explicitly set `base` to `dependency-benchmark-642`, not `main`. Do not touch an existing PR. Reconcile every frozen candidate. In particular, update or specifically defer compatible `parallel` 1.28.0; disclose aube 2.2.10/2.2.11 credential and URL-userinfo redaction, fnox 1.34.1 secret-boundary fixes included in 1.35.0, and Claude 2.1.259/2.1.260 permission-boundary fixes behind the retained snooze; remove or qualify the hk highlight because `hk.pkl` imports 1.39.0 and ShellCheck partial fixing is not configured. Keep applicability and rollback guidance concrete and the report below 500 visible words. Preserve snoozes and use native package managers only. Use one attempt; do not launch another model or workflow, merge, or push main. This repair has 27 AIC for selection and 5 for detection; total V3 lifecycle must stay below 100 AIC.
