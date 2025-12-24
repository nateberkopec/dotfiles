---
name: env-to-fnox
description: This skill should be used when users want to migrate from .env files to fnox with 1Password (or another secret provider). It covers installing fnox, creating 1Password items, configuring fnox.toml, and integrating with mise. Use when users mention ".env migration", "fnox setup", "1password secrets", or want to improve their secret management workflow.
---

# Migrate from .env to fnox + 1Password

This skill guides the migration from plaintext `.env` files to fnox with 1Password as the secret provider. fnox is provider-agnostic and supports multiple backends (1Password, AWS Secrets Manager, Azure Key Vault, HashiCorp Vault, age encryption, etc.).

## Prerequisites

Before starting, verify:
1. 1Password CLI is installed: `op --version`
2. User is authenticated to 1Password: `op vault list`
3. mise is installed (optional but recommended): `mise --version`

## Migration Workflow

### Step 1: Analyze Existing .env

Read the existing `.env` file to understand what secrets need migration:

```bash
cat .env
```

Categorize the secrets:
- **Cloud provider credentials** (AWS_*, ARM_*, GOOGLE_*)
- **API tokens** (CLOUDFLARE_*, GITHUB_*, etc.)
- **Application secrets** (DATABASE_URL, API_KEY, etc.)
- **Configuration values** (non-secret defaults like regions)

### Step 2: Install fnox

Install fnox via mise (recommended):

```bash
mise use fnox
```

Or add to `mise.toml`:

```toml
[tools]
fnox = "latest"
```

Initialize fnox configuration:

```bash
mise exec -- fnox init
mise exec -- fnox provider add op 1password
```

### Step 3: Create 1Password Item

Create a single 1Password item containing all secrets. Use the API Credential category for organization:

```bash
op item create \
  --category="API Credential" \
  --title="project-name" \
  --vault="Private" \
  'Field Name[text]=value' \
  'Secret Field[password]=secret-value'
```

Field naming conventions:
- Use descriptive names: "AWS Access Key ID" not "aws_key"
- Use `[text]` for non-sensitive values (IDs, regions, emails)
- Use `[password]` for sensitive values (secrets, tokens, keys)

Example for a typical project:

```bash
op item create \
  --category="API Credential" \
  --title="myproject" \
  --vault="Private" \
  'AWS Access Key ID[text]=AKIA...' \
  'AWS Secret Access Key[password]=...' \
  'Database URL[password]=postgres://...' \
  'API Token[password]=...'
```

### Step 4: Configure fnox.toml

Update `fnox.toml` to reference the 1Password item:

```toml
[providers.op]
type = "1password"
vault = "Private"

[secrets]
# Format: ENV_VAR = { provider = "op", value = "item-title/Field Name" }
AWS_ACCESS_KEY_ID = { provider = "op", value = "myproject/AWS Access Key ID" }
AWS_SECRET_ACCESS_KEY = { provider = "op", value = "myproject/AWS Secret Access Key" }
DATABASE_URL = { provider = "op", value = "myproject/Database URL" }

# Non-secret defaults don't need 1Password
AWS_DEFAULT_REGION = { default = "us-east-1" }
```

### Step 5: Integrate with mise

Update `mise.toml` to use fnox instead of `.env`:

```toml
[tools]
fnox = "latest"
# ... other tools

[env]
_.source = "fnox export"
```

Remove the old `.env` reference:
```diff
- _.file = ".env"
+ _.source = "fnox export"
```

### Step 6: Verify and Clean Up

Test the configuration:

```bash
# List configured secrets
mise exec -- fnox list

# Verify a secret can be retrieved
mise exec -- fnox get AWS_ACCESS_KEY_ID

# Test full environment
mise exec -- printenv | grep AWS_
```

Once verified, delete the old `.env` file:

```bash
rm .env
```

Commit `fnox.toml` (it contains no secrets, only references):

```bash
git add fnox.toml mise.toml
git commit -m "Migrate secrets from .env to fnox + 1Password"
```

## fnox.toml Reference

### Provider Configuration

```toml
# 1Password
[providers.op]
type = "1password"
vault = "Private"
# account = "my.1password.com"  # Optional: specify account

# Age encryption (for git-stored encrypted secrets)
[providers.age]
type = "age"
recipients = ["age1..."]

# AWS Secrets Manager
[providers.aws]
type = "aws-sm"
region = "us-east-1"
prefix = "myapp/"
```

### Secret Reference Formats

```toml
[secrets]
# 1Password: item-title/field-name
SECRET = { provider = "op", value = "myproject/Secret Field" }

# 1Password: full op:// URI
SECRET = { provider = "op", value = "op://Vault/Item/Field" }

# Default value (no provider needed)
REGION = { default = "us-east-1" }

# Age-encrypted value
SECRET = { provider = "age", value = "YWdlLWVu..." }
```

### Profiles for Multiple Environments

```toml
[providers.op]
type = "1password"
vault = "Development"

[secrets]
DATABASE_URL = { provider = "op", value = "dev-db/url" }

[profiles.production.providers.op]
vault = "Production"

[profiles.production.secrets]
DATABASE_URL = { provider = "op", value = "prod-db/url" }
```

Use profiles with: `FNOX_PROFILE=production fnox export`

## Troubleshooting

### "No configuration file found"
Run `fnox init` to create `fnox.toml`, or check that you're in the correct directory.

### 1Password authentication errors
Ensure you're signed in: `op signin` or check that "Integrate with other apps" is enabled in 1Password Settings > Developer.

### Secrets not loading in shell
If using mise, ensure `mise trust` has been run for the project directory.

### fnox command not found after mise install
Use `mise exec -- fnox` or restart your shell to pick up the new PATH.
