#!/bin/bash
set -euo pipefail

sha="${1:?usage: tag_golden.sh SHA}"
api="https://api.github.com/repos/$GITHUB_REPOSITORY/git/refs"
headers=(-H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28")

if ! curl -fsS -X PATCH "${headers[@]}" "$api/tags/$TAG" -d "{\"sha\":\"$sha\",\"force\":true}" >/dev/null 2>&1; then
    curl -fsS -X POST "${headers[@]}" "$api" -d "{\"ref\":\"refs/tags/$TAG\",\"sha\":\"$sha\"}" >/dev/null
fi
echo "$TAG -> $sha"
