---
name: writing-great-skills
description: Review or edit a skill for predictable invocation, execution, progressive disclosure, and low context cost.
license: "MIT; copyright Matt Pocock; see ../matt-pocock-skills-LICENSE.txt"
source: https://github.com/mattpocock/skills/tree/main/skills/productivity/writing-great-skills
disable-model-invocation: true
---

# Writing great skills

Optimize for **predictability**: the same process across runs, not identical output. Look up a bold term in [GLOSSARY.md](GLOSSARY.md) only when its precise definition or caveats affect the edit; the glossary is authoritative for vocabulary.

## Invocation

`disable-model-invocation` is the authoritative switch:

- Omit it for a **model-invoked** skill. Write a concise model-facing `description` that leads with the action and names one distinct trigger per branch.
- Set it to `true` for a **user-invoked** skill. Keep a concise human-facing description, without spending words on autonomous trigger synonyms.

Choose model invocation only when autonomous or cross-skill discovery earns its permanent **context load**. Use a user-invoked **router skill** when humans must remember too many manual skills.

## Arrange information

Keep universal ordered **steps**, safety rules, branch selection, and checkable **completion criteria** in `SKILL.md`. Keep flat reference inline only when every run needs it. Move branch-specific detail behind a **context pointer** that says exactly when to read the target. Co-locate a concept’s rules and caveats in one authoritative place.

Split by invocation only for an independently discoverable action. Split by sequence only after sharpening a completion criterion fails to prevent **premature completion**.

## Prune

1. Check each sentence in isolation: if deleting it would not change behavior, delete the **no-op**.
2. Remove **duplication** and stale **sediment** rather than polishing it.
3. Cure **sprawl** through progressive disclosure or a justified branch/sequence split.
4. Prefer positive target behavior; retain negation only for a hard guardrail and pair it with what to do.
5. Use a strong pretrained **leading word** when it can replace repeated explanation without losing precision.
6. Convert fixed deterministic pipelines into tested scripts; leave judgment in instructions.

Review every description, body line, pointer, reference, and script claim. Completion means invocation has one unambiguous switch, each meaning has one source of truth, mandatory behavior stays visible, conditional detail loads only when needed, deterministic claims are testable, and every remaining sentence changes behavior.
