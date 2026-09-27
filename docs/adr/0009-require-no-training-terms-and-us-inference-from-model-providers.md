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

Pi's datasafe policy has two startup modes in one shared agent directory. Plain `pi` defaults to `usa-no-train`: unapproved models are hidden from the picker and model list, and requests to them are blocked before HTTP. An explicit `pi-unsafe` fish wrapper starts Pi in `unrestricted`, making every configured provider and model available without Pi's US-routing or no-training request restrictions; account-level settings may still apply. There is no project marker or in-session mode switch: changing modes requires starting another session. The footer displays `[WARNING: UNRESTRICTED]` only while unrestricted. Child sessions inherit the effective mode and enforce the same restrictions. There is no silent fallback to another provider or model.

A single datasafe extension owns startup mode selection, approvals, the warning, and provider-specific enforcement formerly split among the OpenRouter, Fireworks, and Vercel policy extensions. Providers with different catalog or request behavior by mode use mode-specific strategies; providers wholly unapproved in `usa-no-train` are hidden and blocked instead. An absent or invalid mode selection fails closed to `usa-no-train`. New providers and web capabilities are unrestricted-only until approved and recorded in this table. Gateway upstreams are governed by the gateway's verified routing controls rather than listed individually. Exa Search and Contents are allowed under the account's ZDR setting; Exa Answer and Research are unrestricted-only until their no-training coverage is established. A future move to Exa MCP may use separate per-mode MCP configurations, but must preserve these capability-level restrictions. These restrictions are requirements for #731, not controls already implemented in Pi.

The verification table below covers every provider Pi is logged in to. Logging in to a new provider requires adding a row. Entries are re-checked only when a provider is added or changed, or an external event prompts it.

In the configured `pi-web-providers@3.5.1`, `web_answer` calls Exa's `answer()` API directly, so it cannot inherit Search's ZDR coverage. `web_research` calls Exa's `research.create()` / `research.get()` API, which uses `/research/v1`, not the `/agent/runs` API. Exa lists Agent as ZDR-supported but does not list Research; do not assume Agent coverage extends to Research.

## Verification table

Checked 2026-09-24; Exa ZDR status updated 2026-09-27; OpenRouter and Vercel request controls updated 2026-09-28.

| Provider | Operator | US inference | No-training basis | Status |
|---|---|---|---|---|
| openai (API key) | OpenAI, US | first-party | [API data not used for training since March 2023](https://developers.openai.com/api/docs/guides/your-data) | compliant |
| openai-codex (ChatGPT Pro) | OpenAI, US | first-party | ["Improve the model for everyone"](https://help.openai.com/en/articles/7730893-data-controls-faq) off, confirmed 2026-09-24 | compliant |
| meridian (Claude Max) | Anthropic, US | first-party | [model improvement setting](https://privacy.claude.com/en/articles/10023580-is-my-data-used-for-model-training) off, confirmed 2026-09-24 | compliant |
| google-vertex | Google Cloud, US | US multi-region endpoint | [Cloud Data Processing Addendum, Section 17 training restriction](https://docs.cloud.google.com/gemini-enterprise-agent-platform/resources/zero-data-retention) | compliant |
| fireworks | Fireworks, US | US endpoint, documented US-only routers, non-US IDs blocked | [privacy policy](https://fireworks.ai/privacy-policy), no training without explicit opt-in | compliant |
| openrouter | OpenRouter, US; upstreams vary | US endpoint, catalog filtered to US availability | [account toggle](https://openrouter.ai/docs/guides/privacy/provider-logging) off for paid models, confirmed 2026-09-24; [`provider.data_collection: deny`](https://openrouter.ai/docs/guides/routing/provider-selection) injected 2026-09-28 | compliant |
| vercel-ai-gateway | Vercel, US; upstreams vary | `inferenceRegion` US zone injected | [Vercel does not train](https://vercel.com/docs/ai-gateway/faq); [`disallowPromptTraining: true`](https://vercel.com/docs/ai-gateway/security-and-compliance/disallow-prompt-training) injected 2026-09-28 | compliant |
| exa (web tools) | Exa, US | US company | Account ZDR enabled, confirmed by account owner 2026-09-27. [ZDR availability](https://exa.ai/docs/admin/security/zero-data-retention) covers Search and Contents, but explicitly excludes Answer; Research is not listed. Without ZDR, [Exa's privacy policy](https://exa.ai/privacy-policy) permits use of query data to train models. | Search and Contents: `usa-no-train`; Answer and Research: unrestricted only pending separate no-training evidence |

OpenRouter's [account opt-out](https://openrouter.ai/docs/guides/privacy/provider-logging) already blocks training upstreams for paid models, so `data_collection: deny` adds no restriction while that opt-out remains enabled; it makes the constraint explicit per request and also covers the separately configured free-model setting. Vercel's [own no-training policy](https://vercel.com/docs/ai-gateway/security-and-compliance/disallow-prompt-training) does **not** filter upstreams by default: `disallowPromptTraining: true` does. It would be redundant if [team-wide ZDR](https://vercel.com/docs/ai-gateway/security-and-compliance/zdr) is enabled (not verified here), since ZDR implies no training; Vercel says the request flag does not enforce the restriction on BYOK traffic.

## Consequences

- [#731](https://github.com/nateberkopec/dotfiles/issues/731): implement launch-time datasafe modes in one shared Pi agent directory, including the `pi-unsafe` fish wrapper, picker hiding, request block, visible warning, provider strategies, and per-capability web-tool rules. Keep Exa Answer and Research unrestricted-only until their coverage is established.
- [#732](https://github.com/nateberkopec/dotfiles/issues/732): completed; OpenRouter and Vercel request controls are in place and must become mode-aware in #731.
- [#733](https://github.com/nateberkopec/dotfiles/issues/733): closed; Exa ZDR was enabled on the account, so replacing Exa is no longer planned. The remaining Answer and Research exceptions are tracked in #731.
