# GitHub access for agents

Agents use the private [gh-agent app](https://github.com/nateberkopec/gh-agent)
through Executor on **server-1**. This implements the PAT-backed routing portion
of [#628](https://github.com/nateberkopec/dotfiles/issues/628). No GitHub App
installation or OAuth callback is required; writes are attributed to the PAT
owner, without a separate app badge.

The source of truth is the private gh-agent repository. Dotfiles manages agent
instructions, not a second copy of the app or credentials. The server's managed
bundler workaround remains tracked separately in
[upstream-workarounds.md](upstream-workarounds.md).

## Connect and select access

1. Sign in to Executor at `https://server-1.tail6cc978.ts.net`.
2. Open gh-agent and its Accounts view.
3. Connect the `github` requirement with provider **GitHub (PAT)**. Enter the
   token only in the authenticated browser form, never in chat, source, tool
   arguments, or deployment files.
4. Give each saved connection a descriptive access-boundary label. Use separate
   profiles when an agent should be able to select among several connections.
   Each profile selects exactly one PAT; profiles share the app's code.
5. Rediscover tools in a new Executor execution after changing a selection.

A profile is a credential selection, not an authorization boundary by itself.
Restrict Executor grants to the intended profiles and constrain the PATs at
GitHub. A caller allowed to use multiple profiles can choose among them.
Agents must not silently switch to a more privileged account after a denial.

Prefer fine-grained PATs for selected repositories and permissions. Classic
PATs may be necessary for public upstream contributions; `public_repo` covers
public repository operations, while `repo` also grants broad private-repository
access. Organization policy, approval, and SSO can impose additional limits.
Use expiration dates and rotate tokens through Executor; PATs are not refreshed
automatically. See [GitHub's PAT documentation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens).

## Tools, models, and disclosure

The app dynamically reads GitHub's hosted MCP catalog at
`https://api.githubcopilot.com/mcp/x/all`. Discovery and calls use the selected
connection; catalog caching is account/credential scoped. Exposing a tool does
not grant permission to execute it. Only explicitly read-only tools become
queries; mutations with unreviewed string fields are withheld pending review.

Discover exact signatures through Executor before calling tools. Every mutation
requires the writing model's actual runtime ID in `model` (`PI_MODEL` in Pi).
Missing, blank, unknown, and placeholder models are rejected. The proxy strips
that argument before forwarding to GitHub and generates this line for nonempty
prose `body`:

```text
_This is AI-assisted. Model: <model>_
```

Edits replace an existing disclosure instead of duplicating it. Do not add it
manually. Titles, identifiers, source contents, and commit messages are not
decorated. Existing approval and communication rules remain in force.

Use gh-agent rather than CLI or web search for agent GitHub operations. If an
operation is not exposed, the app is unavailable, or the selected PAT lacks
access, stop and ask; do not fall back to other credentials. The upstream MCP
tool catalog is not the entire GitHub REST/GraphQL API.

## Verified behavior

PAT deployment was verified on server-1, with 99 upstream tools exposed
(64 queries and 35 mutations). Integration tests created and closed:

- [dotfiles #819](https://github.com/nateberkopec/dotfiles/issues/819): issue
  creation, comment, body edit without duplicate disclosure, unchanged title,
  rejection of missing/blank/unknown models, and body-preserving closure.
- [Puma #4034](https://github.com/puma/puma/issues/4034): the same checks with a
  separately selected connection labeled Classic. The previous connection
  received a GitHub 403 on issue creation; no issue was created with that token.

Issue and comment authors were `nateberkopec`. Readback confirmed invalid-model
attempts left the body unchanged and both test issues were closed. The app's
16 local tests include synthetic SDK checks for separate connection tokens.
These tests do not establish permissions for every tool or repository, or
prove isolation between independently granted callers.

Blank/placeholder model failures currently appear as Executor's generic 502
rather than a useful validation error. Enforcement passed; error reporting is
still rough. A generic tool failure does not prove a write was not applied:
inspect state before retrying an uncertain write.

## Git authentication is separate

Agent routing does not replace authenticated `git push`/`git fetch`. The managed
Git config still uses `!gh auth git-credential` for GitHub and Gist HTTPS access.
**Keep `gh` logged in** until a replacement credential method is chosen and
verified. This change does not migrate Git credentials, change remotes, remove
human shell helpers, or alter CI's GitHub authentication.

The abandoned GitHub App registration is not used by gh-agent. Deleting the
registration and revoking its OAuth authorization/client secret are browser
cleanup tasks; changing app code does not perform that cleanup.

Merging these instructions does not converge the main machine. Running
`dotf run` requires separate authorization.
