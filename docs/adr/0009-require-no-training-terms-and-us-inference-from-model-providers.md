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

Inference must also run in the US and credibly subject to US rule of law. Anthropic's [September 2026 threat report](https://www.anthropic.com/news/detecting-and-preventing-distillation-attacks) found Moonshot and DeepSeek routing user requests to Claude through intermediary platforms and presenting the output as their own. For this reason, I only trust US jurisdiction and rule of law.

I enforce this in multiple places:

* Account level settings and restrctions (documented but not really enforced here)
* A safe agent configuration (enforced here)

## Decision

A service provider is compliant with this "data safe policy" when both hold:

1. It has written no-training terms in legal terms or official documentation. Marketing pages are not sufficient.
2. Its inference compute runs in a US region, under US jurisdiction.

Model author is irrelevant. Data at rest, gateway processing, and TLS termination are out of scope at this time.

The big two US labs (OpenAI, Anthropic) are approved by default. This introduces some ambiguity because OpenAI and Anthropic don't necessarily guarantee inference is performed in the US. However, I basically think these companies are too important and under too much scrutiny to be mishandling data, so for them we basically only require premise 1.

OpenAI offers [US regional processing through `https://us.api.openai.com/v1`](https://developers.openai.com/api/docs/guides/your-data) for supported API endpoints and models, subject to account eligibility and regional configuration. We do not currently use this endpoint because it is not available for our ChatGPT Pro subscription workloads (Sign in with ChatGPT), which still rely on the OpenAI exception above.

Anthropic offers [US-only inference controls for its first-party API](https://platform.claude.com/docs/en/manage-claude/data-residency): `inference_geo: "us"` on Claude 4.6 and later, with workspace-level restrictions available to enforce US-only routing. These API controls are not currently available to us for Claude Max subscription workloads, including Meridian, so those workloads still rely on the Anthropic exception above.

Sometimes a provider/upstream has multiple inference services, only some of which guarantee no-train (e.g.: Google Vertex vs Antigravity). In that case, we do only use no-train endpoints. 

Code-level enforcement is scoped to Pi, including Pi's web-search providers. Wispr Flow dictation is manually verified against the same policy. I really only use Pi and occasionally Codex or Claude directly, and I don't need code-level enforcement of the latter two (though I have checked the 'don't train on me bro' boxes, documented below). Meridian is governed as the Anthropic account behind it.

## How it's enforced operationally

1. I maintain the table below for providers I actually use, and I manually verify that the appropriate account level settings are checked.
2. We have a "datasafe" pi extension I use by default, which ensures I can't accidentlly use upstream providers or tools which are contrary to this policy.

## Verification table

Provider-specific verification dates are noted below. This only reflects providers I actually use.

| Provider | Operator | US inference | No-training basis | Status |
|---|---|---|---|---|
| openai (API key) | OpenAI, US | first-party | [API data not used for training since March 2023](https://developers.openai.com/api/docs/guides/your-data) | compliant |
| openai (Sign in with ChatGPT, ChatGPT Pro) | OpenAI, US | first-party | ["Improve the model for everyone"](https://help.openai.com/en/articles/7730893-data-controls-faq) off, confirmed 2026-09-24 | compliant |
| meridian (Claude Max) | Anthropic, US | first-party | [model improvement setting](https://privacy.claude.com/en/articles/10023580-is-my-data-used-for-model-training) off, confirmed 2026-09-24 | compliant |
| google-vertex | Google Cloud, US | US multi-region endpoint | [Cloud Data Processing Addendum, Section 17 training restriction](https://docs.cloud.google.com/gemini-enterprise-agent-platform/resources/zero-data-retention) | compliant |
| fireworks | Fireworks, US | US endpoint, documented US-only routers, non-US IDs blocked | [privacy policy](https://fireworks.ai/privacy-policy), no training without explicit opt-in | compliant |
| openrouter | OpenRouter, US; upstreams vary | US endpoint, catalog filtered to US availability | [account toggle](https://openrouter.ai/docs/guides/privacy/provider-logging) off for paid models, confirmed 2026-09-24; [`provider.data_collection: deny`](https://openrouter.ai/docs/guides/routing/provider-selection) injected 2026-09-28 | compliant |
| vercel-ai-gateway | Vercel, US; upstreams vary | `inferenceRegion` US zone injected | [Vercel does not train](https://vercel.com/docs/ai-gateway/faq); [`disallowPromptTraining: true`](https://vercel.com/docs/ai-gateway/security-and-compliance/disallow-prompt-training) injected 2026-09-28 | compliant |
| typesafe (Jev API) | TypeSafe AI, Inc., US | [Privacy policy](https://typesafe.ai/legal/privacy-policy): Services, including APIs, hosted in the US; US storage and processing | [Terms of Service](https://typesafe.ai/terms-and-conditions) and privacy policy prohibit training or fine-tuning on inputs; [MCA §4.1](https://typesafe.ai/legal/mca) prohibits training on inputs and outputs without prior customer consent. No-training, not a ZDR claim. Reviewed 2026-10-05. | compliant |
| wispr-flow (dictation) | [Wispr AI, Inc., Delaware](https://wisprflow.ai/legal/dpa) | [Official security documentation](https://docs.wisprflow.ai/articles/3467817258-security-and-compliance-faq): customer data processed in the US | ["Improve the model for everyone"](https://docs.wisprflow.ai/articles/3842996553-privacy-mode-private-cloud-sync) off, confirmed by account owner 2026-10-08; no training by Wispr or third parties. [Data Controls](https://wisprflow.ai/data-controls) prohibit subprocessor training. Feedback submissions excluded; see below. | compliant for dictation with training disabled and no confidential feedback submissions |
| exa (web tools) | Exa, US | US company | Account ZDR enabled, confirmed by account owner 2026-09-27. [ZDR availability](https://exa.ai/docs/admin/security/zero-data-retention) covers Search and Contents, but explicitly excludes Answer; Research is not listed. Without ZDR, [Exa's privacy policy](https://exa.ai/privacy-policy) permits use of query data to train models. | Search and Contents: `usa-no-train`; Answer and Research: unrestricted only pending separate no-training evidence |

Wispr Flow's training opt-out was previously called "Privacy Mode" (on means opted out); the current "Improve the model for everyone" toggle must be off. Its [Data Controls](https://wisprflow.ai/data-controls) separately permit model training on session data submitted through ratings, reports, or other feedback, without clearly exempting opted-out accounts. Do not submit confidential dictations through those feedback paths. Dictation Cloud Storage is independent of the training setting; disabling it reduces retention but is not required by this policy. This verification covers dictation, not Notetaker or Scratchpad.

If you're a Speedshop customer, in the absence of any other agreement between us, I only use the compliant providers and tools above to work on your project.
