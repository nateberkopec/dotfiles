---
name: env-to-fnox
description: Migrate a dotenv file to fnox backed by 1Password. Use when replacing plaintext `.env` secrets with runtime references.
---

# Migrate dotenv secrets to fnox

Keep secret values outside the conversation, command arguments, logs, and persistent temporary files. Inject them into application process environments only through fnox at runtime. Never read or print the dotenv file. Use the bundled migration script; it parses the file locally, sends a concealed-field item template to `op` over stdin, and writes only `op://` references to `fnox.toml`.

## Preconditions

1. Confirm `ruby`, `op`, and `fnox` are installed.
2. Authenticate `op` outside the conversation (`op vault list` may confirm status; suppress its output).
3. Confirm the source uses simple dotenv assignments. The script rejects interpolation, command substitution, `export`, multiline values, and ambiguous quoting rather than evaluating them.
4. Ensure `fnox.toml` and the dotenv source are ignored or intentionally tracked as appropriate. The generated config contains references, not values.

## Migrate

Preview names only:

```sh
~/.claude/skills/env-to-fnox/scripts/migrate_env_to_fnox.rb \
  --env-file .env --vault Private --item-title myproject --dry-run
```

Ask the user to approve the variable-name summary. Then migrate:

```sh
~/.claude/skills/env-to-fnox/scripts/migrate_env_to_fnox.rb \
  --env-file .env --vault Private --item-title myproject --output fnox.toml --verify
```

The script requires `op item create --template /dev/stdin`; stop if that interface is unavailable. Never fall back to secret-bearing arguments, environment variables, or temporary files.

Review `fnox.toml` by key and reference only. Configure mise with:

```toml
[env]
_.source = "fnox export"
```

Run the application through `fnox exec -- <command>` or mise and check only its exit status. Do not use `fnox get`, `fnox export`, `printenv`, or similar commands without redirecting both output streams away from the conversation.

## Remove the source

Retain `.env` by default. Only after the application succeeds and the user explicitly asks to remove it, rerun with `--delete-source`. The script requires typing `DELETE`; declining leaves the source intact.

Completion means every previewed key has a concealed 1Password field, `fnox.toml` contains only references, status-only verification succeeds, and the source was retained unless deletion was explicitly confirmed.
