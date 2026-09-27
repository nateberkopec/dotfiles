# Require no-training terms and US inference from model providers

## Status

Accepted

## Context

Most client work requires a no-training promise attached to every model interaction. Zero data retention is not required, but a written commitment not to train on prompts and outputs is.

Inference must also run in the US and be operated by a US company. Anthropic's [September 2026 threat report](https://www.anthropic.com/news/detecting-and-preventing-distillation-attacks) found Moonshot and DeepSeek routing user requests to Claude through intermediary platforms and presenting the output as their own. A non-US operator that makes no explicit no-training statement is not trusted with client data.

Neither rule can be fully enforced by code. Several of the controls are account-level settings on consumer plans, and some providers offer no request-time control at all. This ADR therefore also serves as a dated log of how and when each provider was checked.

## Decision

A provider is compliant when both hold:

1. It has written no-training terms in legal terms or official documentation. Marketing pages are not sufficient.
2. Its inference compute runs in a US region operated by a US company.

Model author is irrelevant; only the operator of the inference service matters. Data at rest, gateway processing, and TLS termination are out of scope.

Both rules are enforced at request time wherever the provider API offers a control, and the request fails rather than rerouting. Where no control exists, the verification table says so explicitly.

First-party US labs (OpenAI, Anthropic, Google) are approved by default, subject to rule 1. This is why Google models are used through Vertex rather than Antigravity.

Scope is Pi only, including Pi's web-search providers. Meridian is governed as the Anthropic account behind it. Claude Code and Codex CLI share accounts with Pi's providers, so they are covered at the account level rather than separately. The dependency factory is out of scope. There is no provider preference order.

Pi has two modes. `usa-no-train` mode is the default everywhere: models from providers not approved for that mode are hidden from the picker and model list, and requests to them are blocked in the provider hook. Open mode allows everything. A project marker sets the default for a directory, a per-session command overrides it, and open mode is visibly indicated while active. Web tools obey the same switch **per capability**, rather than treating every endpoint of a provider as approved together. Exa Search and Contents are allowed under the account's ZDR setting; Exa Answer and Research are available only in open mode until their no-training coverage is established. Switching modes must not silently fall back to another provider.

The verification table below covers every provider Pi is logged in to. Logging in to a new provider requires adding a row. Entries are re-checked only when a provider is added or changed, or an external event prompts it.

In the configured `pi-web-providers@3.5.1`, `web_answer` calls Exa's `answer()` API directly, so it cannot inherit Search's ZDR coverage. `web_research` calls Exa's `research.create()` / `research.get()` API, which uses `/research/v1`, not the `/agent/runs` API. Exa lists Agent as ZDR-supported but does not list Research; do not assume Agent coverage extends to Research. These are policy requirements for #731, **not controls already implemented in Pi**.

## Verification table

Checked 2026-09-24; Exa ZDR status updated 2026-09-27.

| Provider | Operator | US inference | No-training basis | Status |
|---|---|---|---|---|
| openai (API key) | OpenAI, US | first-party | [API data not used for training since March 2023](https://developers.openai.com/api/docs/guides/your-data) | compliant |
| openai-codex (ChatGPT Pro) | OpenAI, US | first-party | ["Improve the model for everyone"](https://help.openai.com/en/articles/7730893-data-controls-faq) off, confirmed 2026-09-24 | compliant |
| meridian (Claude Max) | Anthropic, US | first-party | [model improvement setting](https://privacy.claude.com/en/articles/10023580-is-my-data-used-for-model-training) off, confirmed 2026-09-24 | compliant |
| google-vertex | Google Cloud, US | US multi-region endpoint | [Cloud Data Processing Addendum, Section 17 training restriction](https://docs.cloud.google.com/gemini-enterprise-agent-platform/resources/zero-data-retention) | compliant |
| fireworks | Fireworks, US | US endpoint, documented US-only routers, non-US IDs blocked | [privacy policy](https://fireworks.ai/privacy-policy), no training without explicit opt-in | compliant |
| openrouter | OpenRouter, US; upstreams vary | US endpoint, catalog filtered to US availability | [account toggle](https://openrouter.ai/docs/guides/privacy/provider-logging) off for paid models, confirmed 2026-09-24; `data_collection: deny` not yet sent | enforcement pending |
| vercel-ai-gateway | Vercel, US; upstreams vary | `inferenceRegion` US zone injected | [Vercel does not train](https://vercel.com/docs/ai-gateway/faq); [`disallowPromptTraining`](https://vercel.com/docs/ai-gateway/security-and-compliance/disallow-prompt-training) not yet sent | enforcement pending |
| exa (web tools) | Exa, US | US company | Account ZDR enabled, confirmed by account owner 2026-09-27. [ZDR availability](https://exa.ai/docs/admin/security/zero-data-retention) covers Search and Contents, but explicitly excludes Answer; Research is not listed. Without ZDR, [Exa's privacy policy](https://exa.ai/privacy-policy) permits use of query data to train models. | Search and Contents: `usa-no-train`; Answer and Research: open only pending separate no-training evidence |

## Consequences

- [#731](https://github.com/nateberkopec/dotfiles/issues/731): implement `usa-no-train` and open modes, including the project marker, session override, picker hiding, request block, visible indicator, and per-capability web-tool switch. Keep Exa Answer and Research out of `usa-no-train` until their coverage is established.
- [#732](https://github.com/nateberkopec/dotfiles/issues/732): send `data_collection: deny` on OpenRouter requests and `disallowPromptTraining: true` on Vercel requests, failing closed.
- [#733](https://github.com/nateberkopec/dotfiles/issues/733): closed; Exa ZDR was enabled on the account, so replacing Exa is no longer planned. The remaining Answer and Research exceptions are tracked in #731.
