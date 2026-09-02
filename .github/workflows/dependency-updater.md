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
    run: |
      mkdir -p /tmp/gh-aw/agent
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
    run: bundle exec ruby tools/ci/dependency_candidates.rb /tmp/gh-aw/agent/dependency-candidates.json

post-steps:
  - name: Require a pull request outcome
    run: |
      jq -e '[.items[] | select(.type == "create_pull_request" or .type == "push_to_pull_request_branch" or .type == "add_comment")] | length > 0' /tmp/gh-aw/agent_output.json > /dev/null \
        || { echo "::error::The agent finished without creating, updating, or commenting on a dependency-update pull request."; exit 1; }
  - name: Verify the dependency report
    run: |
      body=$(jq -r '[.items[] | select(.type == "create_pull_request")][0].body // empty' /tmp/gh-aw/agent_output.json)
      if [ -z "$body" ]; then
        echo "No pull request in the agent output; nothing to verify"
        exit 0
      fi
      printf '%s\n' "$body" > /tmp/gh-aw/agent/pr-body.md
      bundle install
      bundle exec ruby tools/ci/check_dependency_report.rb /tmp/gh-aw/agent/dependency-candidates.json /tmp/gh-aw/agent/pr-body.md "$GITHUB_SHA"

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
    target: "*"
    required-labels: [dependency-update]
  noop: false
---

# Dependency Software Factory

Keep the run context compact:

- Candidates are already discovered in `/tmp/gh-aw/agent/dependency-candidates.json`. Do not enumerate manifests or query registries for versions; spend the run on release notes and judgment.
- Keep raw responses and logs under `/tmp/gh-aw/agent`. Read excerpts smaller than 20 KB, reuse one evidence file, and fetch each release once and only after it passes the gates.
- Use only `[A-Za-z0-9._-]` in temporary filenames so artifact upload remains valid.
- `gh pr list` and `gh issue list` fail with `malformed version` in this sandbox when given search filters such as `--label`, `--author`, `--assignee`, `--search`, or `--draft`. Use `gh api`, or unfiltered `--json` output piped to `jq`, instead.
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

Otherwise, read `/tmp/gh-aw/agent/open-dependency-update-prs.json`. It was written before you started and lists the open pull requests with the `dependency-update` label. If it is not empty, add a comment on that pull request that links this run and says this batch was skipped because the pull request is still open, and make no changes. If it is empty, follow `.github/dependency-updater.md` exactly and make all eligible dependency updates in one pull request.

There is no `noop` tool. Every run must end with a pull request created, a branch pushed, or a comment added. If you cannot finish for any reason, call `report_incomplete` with the reason. That fails the run and opens an issue for Nate.
