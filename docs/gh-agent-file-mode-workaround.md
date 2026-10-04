# Temporary gh-agent file-mode repair

Tracking issue: [#843](https://github.com/nateberkopec/dotfiles/issues/843).
Do not close it when this workaround ships.

## Problem

The hosted GitHub MCP `push_files` operation writes every supplied path as
`100644`, even when the existing file is executable. This broke direct script
execution while publishing [the YSK PR](https://github.com/nateberkopec/dotfiles/pull/842).

- Upstream report: [github/github-mcp-server#2578](https://github.com/github/github-mcp-server/issues/2578).
- Proposed fix: [github/github-mcp-server#3410](https://github.com/github/github-mcp-server/pull/3410).
- Tested upstream patch: [`f91c211322cf5217cf568b7939d05807db311233`](https://github.com/nateberkopec/github-mcp-server/commit/f91c211322cf5217cf568b7939d05807db311233).

## Deployed workaround

The existing gh-agent Executor app has a temporary `mutations.set_file_mode`
operation. It calls GitHub's Git tree, commit, and ref APIs with the same selected
PAT. It accepts only an existing regular file and modes `100644` or `100755`.

The caller must supply the exact expected branch-head and blob SHAs. The operation
reuses the blob, pins the base tree and parent commit, checks the head again, and
updates the ref with `force: false`. It rejects special entries, symlink ancestors,
truncated trees, stale state, and paths above 64 components. It does not retry or
follow redirects. A later API failure can leave unreferenced Git objects; there is
no transactional rollback.

Immutable deployment identities:

- App source commit: `39d2aed1012e4a48bb9bf4efe67945eecd363884`.
- Deployment: `dpl_d483166a-9470-4159-88f8-1d67b87786e2`.
- Previous source commit: `7582dec947813aa435c7edc0119a0985f1416e27`.
- Previous deployment: `dpl_3c8c6d99-db5e-4f5c-99bc-6a1edb9644f4`.

These identify a retained hosted-app build. They are not a managed-installer pin
or a patch-version fork release. This path uses a hosted upstream service whose
release revision is unknown. No runtime dependency or account requirements were
changed, and no scheduled automation was added. This document records the live
workaround; it does not deploy or install it during dotfiles convergence.

## Verification

All 19 app tests passed, including workerd request tests. A strict TypeScript
check of the new module passed. All 14 saved app files matched the tested local
source bytes.

Live repair changed only `tools/typecheck_pi_extensions.sh` from `100644` to
`100755` in dotfiles commit `dbc96b3a645f13ccfa056c6fb92e406ca7fbcb7e`.
Its blob remained `9c77e34f620d28dfa710297d0145bec8907af0ce`; every other leaf
entry remained unchanged. A second live call returned `changed: false` and did
not create a commit. All seven YSK file-content hashes match the tested files.

The upstream regression tests establish public-source handler behavior, not the
hosted service's binary revision. No new upstream report or outreach is needed.

## Remove the workaround

1. Wait for the upstream fix to merge **and reach the hosted MCP service**.
2. Run a synthetic executable-file update through hosted `push_files`. Verify
   that it retains `100755`; also verify explicit creation and mode changes.
3. Review the new `mode` string field in gh-agent's disclosure catalog allowlist.
   Do not weaken the allowlist to expose unreviewed fields.
4. Remove `set_file_mode`, its registration, and its dedicated tests. Deploy and
   verify a new immutable gh-agent revision.
5. Remove this record through a dotfiles PR. Close #843 only after removal ships.

No convergence of the user's main machine was performed for this workaround.
