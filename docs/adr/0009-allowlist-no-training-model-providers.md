# Data safety and upstream providers

## Status

Accepted

## Context

I work extensively for companies who care about their proprietary and confidential information. They have varying policies regarding how/what can be sent to upstream AI providers, but I aim to have a kind of baseline policy that I feel is safe for their intellectual property, confidential information and other secrets.

Today, in late 2026, a fully E2E "sovereign" AI setup with frontier-level intelligence is probably in the mid 5 digits. Additionally, the value provided by $200/mo subscriptions from frontier labs is substantial ($5k of list inference per month), making this tradeoff harder.

This policy was designed so that Speedshop can maintain maximal flexibility and speed in adoption of new models, as the frontier is constantly shifting. It was also designed so that we can safely and responsibly do cybersecurity research on behalf of our clients.

Our policy is:

1. **Minimize the number of entities we must trust, allowlist only**. Prefer to buy directly where possible. Choose network pathing carefully.
2. **Prefer "too big to fail" frontier labs and US hyperscalers**. This list is very short: Google, Amazon, Microsoft, OpenAI and Anthropic.
3. **Do not use routers or anyone who allows 3rd parties to fulfill inference**. In November 2026, [Dragos found that even US-based inference providers and routers were leaking secrets provided under ZDR terms](https://www.dragos.com/blog/ai-supply-chain-security-canary-tokens).
4. **Set ZDR and no-train flags anywhere they are available**. Yes, we cannot audit these directly, but we can use canaries to at least try and double check (more on that later).
5. **Inference providers must be credibly subject to US or EU rule of law.** Anthropic's [September 2026 threat report](https://www.anthropic.com/news/detecting-and-preventing-distillation-attacks) found Moonshot and DeepSeek routing user requests to Claude through intermediary platforms and presenting the output as their own. For this reason, I only trust US or EU jurisdiction and rule of law.
6. **Prefer US and EU data residency and GPU residency**. Unfortunately, due to the constrained global supply of compute, I cannot _limit_ myself to these, but I prefer them where available. Example: Anthropic does not offer US-only residency/compute to subscription customers.

I don't _actually_ trust these upstreams to never train on my data or to not read it, but that is unfortunately the tradeoff I have to make today to access frontier intelligence. I hope, in the near future, to offer sovereign inference to Speedshop clients or to help them set it up themselves.

"No train" does not equal ZDR. I accept some degree of data retention for compliance or legal or whatever other purposes the upstream says. ZDR is frequently, but not necessarily, no train.

Model author is irrelevant. We use open source models regardless of the lab which trained them.

Data at rest, gateway processing, and TLS termination are out of scope at this time because they are difficult to verify without an enterprise contract.

Sometimes a provider/upstream has multiple inference services, only some of which guarantee no-train (e.g.: Google Vertex vs Antigravity). In that case, we do only use no-train endpoints. 

### Client personal data and credentials

These rules apply to all client work:

1. No personal data about a client's customers, end users, or other data subjects goes to any third-party. PII is defined as in [OMB Circular A-130](https://csrc.nist.gov/glossary/term/personally_identifiable_information): "information that can be used to distinguish or trace an individual's identity, either alone or when combined with other information that is linked or linkable to a specific individual." 
2. Client credentials are never sent to any third-party. Agents act through tools that hold these credentials, so credentials are never seen by the inference provider.

## How it's enforced operationally

1. I maintain the table below for providers I actually use, and I manually verify that the appropriate account level settings are checked.
2. We have a "datasafe" pi extension I use by default, which ensures I can't accidentally use upstream providers or tools which are contrary to this policy, and that the appropriate ZDR/no-train flags are included if necessary.
3. Agents reach client systems through a broker that holds the credentials. The model never sees a client credential.

## Verification table

Provider-specific verification dates are noted below. This only reflects providers I actually use.

| Provider | Operator | Inference region | No-training basis | Status |
|---|---|---|---|---|
| openai (API key) | OpenAI, US | first-party | [API data not used for training since March 2023](https://developers.openai.com/api/docs/guides/your-data) | compliant |
| openai (Sign in with ChatGPT, ChatGPT Pro) | OpenAI, US | first-party | ["Improve the model for everyone"](https://help.openai.com/en/articles/7730893-data-controls-faq) off, confirmed 2026-09-24 | compliant |
| claude-code (Claude Max) | Anthropic, US | first-party | [model improvement setting](https://privacy.claude.com/en/articles/10023580-is-my-data-used-for-model-training) off, confirmed 2026-09-24 | compliant |
| google-vertex | Google Cloud, US | US multi-region endpoint | [Cloud Data Processing Addendum, Section 17 training restriction](https://docs.cloud.google.com/gemini-enterprise-agent-platform/resources/zero-data-retention) | compliant |
| baseten (Model APIs) | Baseten Labs, Inc., US | [Shared endpoint, multi-cloud, regions can change](https://docs.baseten.co/inference/model-apis/overview); US-only requires a support-enabled Model APIs compliance policy | [Terms §6.3](https://www.baseten.co/terms-and-conditions/) prohibits training on Customer Content, including Model Outputs; [Security Practices](https://www.baseten.co/security-practices/) commit Model APIs to ZDR for all inputs and outputs. Reviewed 2026-11-20. | compliant, ZDR |
| exa (web tools) | Exa, US | US company | Account ZDR enabled, confirmed by account owner 2026-09-27. [ZDR availability](https://exa.ai/docs/admin/security/zero-data-retention) covers Search and Contents, but explicitly excludes Answer; Research is not listed. Without ZDR, [Exa's privacy policy](https://exa.ai/privacy-policy) permits use of query data to train models. | Search and Contents: `allowlist`; Answer and Research: not usable |

If you're a Speedshop customer, in the absence of any other agreement between us, I only use the compliant providers and tools above to work on your project.

## Regional restrictions

OpenAI offers [US regional processing through `https://us.api.openai.com/v1`](https://developers.openai.com/api/docs/guides/your-data) for supported API endpoints and models, subject to account eligibility and regional configuration. We do not currently use this endpoint because it is not available for our ChatGPT Pro subscription workloads (Sign in with ChatGPT).

Anthropic offers [US-only inference controls for its first-party API](https://platform.claude.com/docs/en/manage-claude/data-residency): `inference_geo: "us"` on Claude 4.6 and later, with workspace-level restrictions available to enforce US-only routing. These API controls are not currently available to us for Claude Max subscription workloads, including Pi's Claude Code provider.
