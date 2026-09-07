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

steps:
  - name: Find open dependency-update pull requests
    env:
      GH_TOKEN: ${{ github.token }}
      PR_NUMBER: ${{ github.event.workflow_run.pull_requests[0].number || github.event.issue.number }}
    run: |
      mkdir -p /tmp/gh-aw/agent
      if [ -n "$PR_NUMBER" ]; then
        gh api "repos/${GITHUB_REPOSITORY}/pulls/$PR_NUMBER" > /tmp/gh-aw/agent/pr.json
        head=$(jq -r .head.sha /tmp/gh-aw/agent/pr.json)
        base=$(jq -r .base.sha /tmp/gh-aw/agent/pr.json)
        base=$(gh api "repos/${GITHUB_REPOSITORY}/compare/$base...$head" --jq .merge_base_commit.sha)
        jq --arg base "$base" '{number, base: $base, head: .head.sha}' /tmp/gh-aw/agent/pr.json > /tmp/gh-aw/agent/pr-context.json
      else
        jq -n --arg base "$GITHUB_SHA" '{base: $base}' > /tmp/gh-aw/agent/pr-context.json
      fi
      gh api "repos/${GITHUB_REPOSITORY}/issues?state=open&labels=dependency-update&per_page=100" \
        --jq '[.[] | select(.pull_request != null) | {number, url: .pull_request.html_url, title}]' \
        > /tmp/gh-aw/agent/open-dependency-update-prs.json
      cat /tmp/gh-aw/agent/open-dependency-update-prs.json
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
  - name: Discover dependency candidates
    env:
      GITHUB_TOKEN: ${{ github.token }}
    run: |
      bundle exec ruby tools/ci/dependency_candidates.rb /tmp/gh-aw/agent/dependency-candidates.json "$(jq -r .base /tmp/gh-aw/agent/pr-context.json)"
      bundle exec ruby tools/ci/dependency_release_notes.rb /tmp/gh-aw/agent/dependency-candidates.json /tmp/gh-aw/agent/release-notes.json
      mkdir -p /tmp/gh-aw/agent/checks
      cp -R tools/ci/dependency_factory tools/ci/dependency_factory.rb tools/ci/check_dependency*.rb /tmp/gh-aw/agent/checks/

post-steps:
  - name: Verify the pull request outcome and report
    run: |
      bundle install
      bundle exec ruby /tmp/gh-aw/agent/checks/check_dependency_output.rb

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
    patch-format: bundle
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
    patch-format: bundle
    github-token: ${{ secrets.DEPENDENCY_FACTORY_PAT }}
    target: "${{ github.event.workflow_run.pull_requests[0].number || github.event.issue.number || 'triggering' }}"
    required-labels: [dependency-update]
    fallback-as-pull-request: false
    if-no-changes: ignore
    allowed-files: *dependency-files
    protected-files: allowed
  update-pull-request:
    target: "${{ github.event.workflow_run.pull_requests[0].number || github.event.issue.number || 'triggering' }}"
    required-labels: [dependency-update]
    title: false
    body: true
  add-comment:
    target: "*"
    required-labels: [dependency-update]
  noop: false
---

# Dependency update

Follow `.github/dependency-updater.md`. Event: `${{ github.event_name }}`; command: `${{ needs.activation.outputs.slash_command }}`.

- **Failed build:** inspect run `${{ github.event.workflow_run.id }}` and its logs. Confirm the dependency-update label and that `${{ github.event.workflow_run.head_sha }}` remains the PR head. Repair only that PR within the mechanical boundary; otherwise remove and snooze the responsible update. Refresh its body and inspect required checks.
- **Slash command:** read the complete triggering PR and apply the user's decisions below to that branch. Refresh its body and reply with decisions and validation.
- **Scheduled/manual run:** read `/tmp/gh-aw/agent/open-dependency-update-prs.json`. If a PR is open, comment there with this run's link and explain that the batch was skipped; make no changes. Otherwise prepare one PR.

> ${{ steps.sanitized.outputs.text }}

Keep logs and evidence in `/tmp/gh-aw/agent`, use filenames containing only `[A-Za-z0-9._-]`, and read excerpts under 20 KB. Use `gh api`: filtered `gh pr list`/`gh issue list` break in this sandbox. Check `/tmp/gh-aw/sandbox/firewall/logs/access.log` for blocked hosts before retrying network failures.

Finish with a PR created, revised, or commented on. If blocked, call `report_incomplete` with the reason; never silently stop. Never merge.
