# Meridian for Pi

Meridian exposes a local Anthropic Messages API backed by the existing Claude Max login. The managed Pi provider is separate from `anthropic`, so installing it does not redirect or replace direct Anthropic use.

## Setup

Authenticate once in an interactive terminal:

```bash
claude auth login
claude auth status
```

On macOS, converge the managed LaunchAgent and configuration:

```bash
cd ~/.dotfiles
./bin/dotf run
```

The agent starts Meridian through the mise-pinned `@rynfar/meridian` installation, binds only to `127.0.0.1:3456`, runs in passthrough mode so Pi executes its own tools, and writes logs to:

- `~/Library/Logs/meridian.out.log`
- `~/Library/Logs/meridian.err.log`

Ubuntu still installs Meridian and the Pi provider through `dotf run`, but managed startup is currently macOS-only. Start it in the foreground on Ubuntu with:

```bash
MERIDIAN_HOST=127.0.0.1 MERIDIAN_PORT=3456 MERIDIAN_PASSTHROUGH=1 mise exec -- meridian
```

## Use

Choose a `meridian/claude-*` model with `/model`, or launch one directly:

```bash
pi --provider meridian --model claude-opus-4-6
```

The provider uses the Anthropic Messages API at `http://127.0.0.1:3456`, sends the required `x-meridian-agent: pi` header, and uses a dummy API key because the loopback service has no API-key authentication enabled. Do not expose this service beyond loopback without configuring Meridian authentication.

The provider copies model capabilities from Pi's built-in Anthropic catalog, limited to models supported by Meridian 1.66.0. The existing Anthropic provider remains unchanged.

Open the local dashboard at <http://127.0.0.1:3456/telemetry>. For a quick health check:

```bash
curl --fail http://127.0.0.1:3456/health
```

If startup or requests fail, check the error log and run `claude auth status`. If it reports that the login expired, run `claude auth login` again (or start `claude` and enter `/login`), then reconverge with `dotf run` or restart the LaunchAgent by logging out and back in.
