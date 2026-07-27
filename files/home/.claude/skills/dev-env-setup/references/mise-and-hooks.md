# mise, tasks, and hooks
### 1. mise Configuration

All dev tools must be managed via mise. Choose the config file based on repo ownership:

- **Your repo** (you are the primary author): use `mise.toml`, commit it.
- **Someone else's repo** (most commits are not yours): preserve tracked configuration and put local additions in `mise.local.toml`, which mise ignores by convention. If the existing project setup cannot be extended locally, report the upstream change needed instead of dirtying the repository.

The config must have a `[tools]` section listing the project's dev dependencies. Inspect the project to determine what tools are needed (language runtimes, linters, formatters, etc.) and add them. `gitleaks` is expected via the global mise config (`~/.config/mise/config.toml`); add it to the project mise config too if the project pins versions in CI.

### 2. Environment Variables and Secrets

Mise must load local environment variables from `.env` using the appropriate mise TOML syntax:

```toml
[env]
_.file = ".env"
```

Rules:

- `.env` contains local environment values. It must never be committed.
- Add `.env` to `.gitignore` for repos Nate owns, or `.git/info/exclude` for someone else's repo when needed.
- `.env.example` must exist and should be committed when this is Nate's repo.
- `.env.example` documents required keys only. It must be a strict subset of `.env`: every key in `.env.example` must also exist in the local `.env`, but `.env` may contain extra keys.
- Keep example values empty or obviously fake, e.g. `DATABASE_URL=` or `STRIPE_API_KEY=replace-me`.
- **Real secrets must not be hardcoded in `.env`.** Any value that is a credential (API token, password, signing key, database URL with embedded password, etc.) must be a reference resolved at runtime, not a plaintext string sitting on disk. The threat model is: an LLM agent or attacker that can read the working tree should not be able to extract a usable secret.
  - Preferred: store the secret in 1Password and reference it from `fnox.toml`. mise loads the resolved environment via `_.source = "fnox export"`. See the `env-to-fnox` skill for migration steps.
  - Acceptable: keep `.env` and use `op://Vault/Item/Field` references that mise resolves at load time.
  - Not acceptable: plaintext credential values in `.env` or any other file in the working tree.
- The audit runs `gitleaks` against the working tree to enforce this — see the **Secret Scanning** section below.
