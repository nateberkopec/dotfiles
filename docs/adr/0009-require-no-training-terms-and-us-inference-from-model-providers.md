# Data safety and upstream providers

## Status

Accepted

## Context

I work extensively for companies who care about their proprietary and confidential information. They have varying policies regarding how/what can be sent to upstream AI providers, but I aim to have a kind of baseline policy that I feel is safe for their intellectual property.

Today, in late 2026, a fully E2E "sovereign" AI setup with frontier-level intelligence is probably in the mid 5 digits. Unfortunately, the value provided by $200/mo provider subscriptions is substantial ($5k of list inference per month), making this tradeoff harder.

My policy is essentially:

> Take trustworthy upstream providers at their word when they say they are ZDR or not training if certain flags are set. Set those flags everywhere. Manually vet who goes on my "trustworthy" list, biasing towards US based inference providers.

I don't _actually_ trust these upstreams to never train on my data, but that is unfortunately the tradeoff I have to make today to access frontier intelligence. I hope, in the near future, to offer sovereign inference to Speedshop clients.

"No train" does not equal ZDR. I accept some degree of data retention for compliance or legal or whatever other purposes the upstream says. ZDR is frequently, but not necessarily, no train.

Inference must also run in the US and be operated by a US company. Anthropic's [September 2026 threat report](https://www.anthropic.com/news/detecting-and-preventing-distillation-attacks) found Moonshot and DeepSeek routing user requests to Claude through intermediary platforms and presenting the output as their own. For this reason, I only trust US jurisdiction and rule of law.

I enforce this in multiple places:

* Account level settings and restrctions (documented but not really enforced here)
* A safe agent configuration (enforced here)

## Decision

A service provider is compliant with this "data safe policy" when both hold:

1. It has written no-training terms in legal terms or official documentation. Marketing pages are not sufficient.
2. Its inference compute runs in a US region operated by a US company.

Model author is irrelevant. Data at rest, gateway processing, and TLS termination are out of scope at this time.

First-party US labs (OpenAI, Anthropic, Google) are approved by default, subject to rule 1. Example: Google Vertex vs Antigravity.

Scope is Pi only, including Pi's web-search providers. I really only use Pi and occasionally Codex or Claude directly, and I don't need code-level enforcement of the latter two (though I have checked the 'don't train on me bro' boxes, documented below). Meridian is governed as the Anthropic account behind it.

## How it's enforced operationally

1. I maintain the table below for providers I actually use, and I manually verify that the appropriate account level settings are checked.
2. We have a "datasafe" pi extension I use by default, which ensures I can't accidentlly use upstream providers or tools which are contrary to this policy.

## Verification table

Current as of September 2026. This only reflects providers I actually use.

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

If you're a Speedshop customer, in the absence of any other agreement between us, I only use the compliant providers and tools above to work on your project.
