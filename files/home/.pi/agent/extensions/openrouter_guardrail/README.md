# OpenRouter guardrail Pi extension

This Pi extension makes Pi's OpenRouter model list match the Speedshop OpenRouter guardrail and adds a throughput picker for guardrailed model/provider routes.

## Goals

- Show only guardrail-approved OpenRouter models in Pi's model list.
- Never trigger 1Password during normal Pi startup, `/model`, or `--list-models`.
- Hide real OpenRouter models when OpenRouter is not authenticated.
- Let explicit OpenRouter commands refresh guardrail and throughput data.
- Make it easy to pick a fast model/provider combination by recent tok/sec.

## Authentication contract

Normal startup uses environment variables only:

- `OPENROUTER_API_KEY`
- `OPENROUTER_PROVISIONING_KEY`

The extension validates `OPENROUTER_API_KEY` with OpenRouter before exposing real models. If the env key is missing or invalid, Pi shows one placeholder model instead of the guardrailed list:

```text
__unlock-1password-for-openrouter-guardrail
```

The extension only reads 1Password when the user explicitly runs one of its OpenRouter commands:

- `/or-refresh`
- `/or-speed`

1Password item references:

```text
op://Employee/Nate Openrouter Key/password
op://Employee/OpenRouter Provisioning Key/password
```

Do not add 1Password fallback to startup, `/model`, or `--list-models`. A 1Password prompt should only happen after an explicit `/or-*` command.

## Caches

The extension stores non-secret cache files under:

```text
~/.pi/agent/cache/openrouter-guardrail-models.json
~/.pi/agent/cache/openrouter-guardrail-performance.json
```

These files contain model IDs, provider names, pricing metadata, latency, and throughput. They must not contain API keys.

## Commands

### `/or-refresh`

Reads the OpenRouter API key and provisioning key from 1Password, fetches the configured guardrail, fetches OpenRouter model metadata, and updates:

```text
openrouter-guardrail-models.json
```

Use this after the guardrail's allowed models/providers change.

### `/or-speed`

Reads the OpenRouter API key and provisioning key from 1Password, fetches endpoint performance for guardrail-approved models, sorts passing model/provider endpoints by `throughput_last_30m.p50`, and opens an interactive picker.

Selecting a row registers a temporary `openrouter-selected` provider route with:

```json
{
  "openRouterRouting": {
    "only": ["selected-provider"],
    "allow_fallbacks": false
  }
}
```

Then it switches Pi to that routed model.

### `/or-speed list`

Shows the sorted rows without opening the picker.

### `/or-speed refresh`

Forces a refresh of endpoint performance data instead of using the short-lived performance cache.

### `/or-speed limit=10`

Limits output/picker rows. Default is 30, maximum is 100.

## Refresh behavior

- Guardrail model cache TTL: 6 hours.
- Endpoint performance cache TTL: 10 minutes.
- Startup may refresh stale guardrail data only when both `OPENROUTER_API_KEY` and `OPENROUTER_PROVISIONING_KEY` are already present in env.
- Startup must not use 1Password to refresh stale data.

## Guardrail assumptions

Default guardrail name:

```text
US Cached Models Only
```

Override with:

```text
OPENROUTER_GUARDRAIL_NAME
```

Performance thresholds default to the guardrail repo defaults:

```text
OPENROUTER_MIN_THROUGHPUT_P50=50
OPENROUTER_MAX_LATENCY_P50=2000
```

## Safety notes

- API keys are passed in memory only and are not written to cache.
- A missing/invalid OpenRouter key fails closed by hiding real OpenRouter models.
- A missing provisioning key prevents refreshes but still allows use of any already-cached model list when the OpenRouter API key is valid.
