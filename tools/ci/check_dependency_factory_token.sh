#!/usr/bin/env bash
# Check the publishing credential before dependency discovery or model execution.
set -euo pipefail

fail() {
    echo "::error::DEPENDENCY_FACTORY_PAT: $1" >&2
    exit 1
}

[ -n "${GH_TOKEN:-}" ] || fail "secret is missing"
gh api user --silent || fail "authentication failed; renew the token"
gh api "repos/${GITHUB_REPOSITORY:?}" --jq '.permissions.push' | grep -qx true ||
    fail "token cannot access the repository with push permission"

# Ignore checkout credentials so only the publishing PAT can satisfy this probe.
header="$(printf 'x-access-token:%s' "$GH_TOKEN" | base64 | tr -d '\n')"
echo "::add-mask::$header"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0=credential.helper GIT_CONFIG_VALUE_0=''
export GIT_CONFIG_KEY_1=http.https://github.com/.extraheader
export GIT_CONFIG_VALUE_1="Authorization: Basic $header"
git -C "${RUNNER_TEMP:?}" ls-remote --exit-code \
    "https://github.com/${GITHUB_REPOSITORY}.git" HEAD >/dev/null ||
    fail "Git HTTPS authentication failed; check token access"

echo "Publishing token passed API and Git read checks; write operations are not exercised."
