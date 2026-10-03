# Temporary upstream workarounds

Keep tracking issues open while a fork is in use. Workaround PRs use `Refs`, not
`Closes`. Remove the workaround only after verifying the official replacement
against the original reproduction and the managed installation path.

## Personal Executor: worker-bundler package subpaths

Tracking issue: [#810](https://github.com/nateberkopec/dotfiles/issues/810).
Upstream report: [cloudflare/agents#2466](https://github.com/cloudflare/agents/issues/2466).

The personal Executor's embedded worker-bundler resolves deep package imports to
legacy root entrypoints. This prevents the GitHub integration in #628 from
deploying. The verified workaround preserves the existing Executor beta.3 image
and runtime dependencies, replacing only the bundled resolver's one-line guard.

Immutable fork pins:

- [Release 0.2.5-nate.2](https://github.com/nateberkopec/agents/releases/tag/worker-bundler-0.2.5-nate.2),
  based on worker-bundler 0.2.4.
- Fork commit: `1f96fe642ef7a4d759d110b6c186a70b7a4e747f`.
- Source patch SHA-256:
  `12b93d372597e877ce5d614e8bb6a7373c2f505630777d37459f963775d81a22`.
- Package tarball SHA-256:
  `75ff3775dd9cf0c756615bb09ada5f919928445721613122d7a324dfac026a3f`.
- Derived ARM64 image ID:
  `sha256:3c932596a0a4fb1fe40ec235e5f73dafa4d2fd74ca7dc2850559a0f49eb9cc1b`.

The server's installer and restore checks belong to
[homelab PR #1](https://github.com/nateberkopec/homelab/pull/1), not `dotf run`.
The pinned build recipe and deployment are recorded at
[homelab commit 635bb5899f4624891fb0ec372185581320c78a6a](https://github.com/nateberkopec/homelab/tree/635bb5899f4624891fb0ec372185581320c78a6a/ansible).
They were verified through a fresh image build, managed installation, isolated
restore check, and successful live app deployment on server-1. Server-2 and the
user's main machine were not converged. Fork Actions are disabled; no schedules
were added.

Before returning upstream, verify that an official Executor image passes both
the public subpath reproduction and the complete GitHub app deployment. Remove
the overlay and temporary pins through homelab, repeat deployment and restore
checks, then remove this entry and close #810. Deleting the fork itself requires
separate permission. GitHub App registration and end-to-end attribution checks
are separate from this deployment workaround.
