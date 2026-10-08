# Meridian integration for Pi

`files/home/.pi/agent/extensions/meridian.ts` registers the `meridian` provider
against `http://127.0.0.1:3456`. It delegates request conversion, extended
thinking, streaming, tools, retries, and usage accounting to Pi's built-in
Anthropic implementation rather than maintaining a second protocol adapter.

## Model and thinking authority

Meridian's `/v1/models` catalog controls the context window, advertised image
and thinking capabilities, adaptive-thinking support, and supported effort
levels. Pi's known model metadata still supplies output limits, prices, image
preprocessing limits, prompt-cache lifetimes, and other API compatibility.
Unknown models use catalog metadata and zero-cost fallback pricing, as before.

Use Pi's existing `/thinking` picker and shortcuts. Supported efforts are mapped
to the same named Pi levels; `minimal` uses `low`. Unsupported efforts are
excluded. Models that advertise adaptive-only thinking cannot select `off`.
No separate Meridian thinking command or widget is installed.

The independent `/compact-at` extension still caps the selected window at 400k
by default, never above Meridian's real window. This integration does not
replace that policy.

A validated raw catalog is cached at `<agent-dir>/cache/meridian-models.json`.
It expires after seven days, is bound to the local endpoint, and is rebuilt
against the current Pi metadata on every startup. A failed refresh retains the
last valid in-memory catalog. An outage with no usable cache leaves Meridian
models unavailable without breaking other providers. Local discovery still
runs in Pi offline mode, as before. Only model metadata is cached, never prompts,
credentials, tools, or request headers.

## Request identity and roles

Normal requests carry the current Pi session ID as `x-session-affinity`.
Explicit affinity remains supported, and case-insensitive header handling
prevents duplicate spellings. The stream boundary also uses each request's own
session ID, so an in-process child cannot inherit the parent's automatic key.
New conversations, resumed sessions, and forks use their own Pi identities.

Primary requests are named `pi`. pi-subagents' tagged `<active_agent>` prompt
provides the child name; its background runner also exposes
`PI_SUBAGENT_CHILD=1`. Child requests use subagent mode and retain their own
conversation identity. Do not treat every non-interactive Pi process as a
subagent: independent headless primary workflows remain primary.

Calls using a different routing session ID without child metadata are auxiliary
`generate` requests. Pi compaction is explicitly classified while its lifecycle
is active and uses its own summarization ID. Our conversation-title extension
marks its direct API call as `title` and uses a separate identity. Unlike
OpenCode's compaction, Pi summarizes a separate prompt, so attaching it to the
main SDK conversation would be incorrect. These auxiliary calls cannot advance
the main conversation's lineage.

Each provider-stream invocation gets `x-request-id` unless the caller supplied
one. Pi's API retries retain that invocation's request identity. This is request
correlation, not an OpenCode human-turn attestation.

## Compatibility with OpenCode's plugin

| Feature | Pi behavior |
|---|---|
| Conversation identity | Pi session affinity, including children and forks |
| Agent role/name | Primary/subagent metadata at provider dispatch |
| Hidden auxiliary isolation | Separate title, generate, and compaction identities |
| Model discovery | Live startup and `/model` refresh, including offline local discovery |
| Context authority | Meridian's advertised window, subject to `/compact-at` |
| Effort variants | Pi's existing `/thinking` levels, not extra model variants |
| Persistent discovery | Validated seven-day endpoint-bound catalog |
| Request identity | Provider-neutral `x-request-id` correlation |
| Task budget | Existing request/header configuration; no new UI |
| Profile pinning | Existing `x-meridian-profile` configuration; no new UI |
| Signed priority failback | Excluded: Meridian only trusts OpenCode human-turn attestations |
| OpenCode version gates | Excluded: tied to OpenCode host APIs |

### Legacy header names: upstream follow-up

Meridian 1.76.5 reads `x-opencode-agent-mode` and `x-opencode-agent-name` for Pi
traffic too. We send those two names because no `x-agent-*` or `x-pi-*` aliases
exist in the installed server. Upstream should add provider-neutral role/name
aliases, retaining the old spellings for compatibility. Until then, these are
wire-contract dependencies, not claims that this client is OpenCode. The
upstream request is tracked in [Meridian #1311](https://github.com/rynfar/meridian/issues/1311).

Thinking and effort already have neutral body fields (`thinking`,
`output_config.effort`, and effort-bearing system messages). Pi's Anthropic
implementation supplies them; there is no need to add `x-opencode-thinking` or
`x-opencode-effort` overrides.

Neither shipped OpenCode plugin installs a task-budget picker or command. For
matching config-only access in Pi, a `models.json` model override can set:

```json
{
  "providers": {
    "meridian": {
      "modelOverrides": {
        "claude-opus-5": {
          "headers": { "x-opencode-task-budget": "50000" }
        }
      }
    }
  }
}
```

Meridian also accepts `body.task_budget`, but Pi's stock Anthropic API does not
expose that field in model configuration. The header is currently the
config-only route. The SDK describes this alpha option as an API-side token
budget that helps the model pace its task. It is **not** a Pi-wide spending cap
or a guaranteed budget across multiple client-owned tool rounds. The default
remains unset. An upstream neutral budget-header alias would remove the remaining
OpenCode naming dependency for this optional setting.

Profile pinning works the same way with `x-meridian-profile`. Advanced
`next-user-turn` priority failback requires an OpenCode-specific signed
attestation; do not forge those headers from Pi.
