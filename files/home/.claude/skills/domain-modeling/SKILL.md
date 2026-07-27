---
name: domain-modeling
description: Build and sharpen a project's domain model. Use to resolve domain terminology, establish ubiquitous language, or record a durable architectural decision.
license: "MIT; copyright Matt Pocock; see ../matt-pocock-skills-LICENSE.txt"
source: https://github.com/mattpocock/skills/tree/main/skills/engineering/domain-modeling
---

# Domain modeling

Use this skill when changing the model, not merely reading an existing glossary.

Locate the applicable `CONTEXT.md`. A root `CONTEXT-MAP.md` indicates multiple contexts and points to each glossary and context-specific ADR directory. Create glossary or ADR files lazily, only when the first entry is ready.

## Loop

1. Challenge terms that conflict with the current glossary.
2. Replace vague or overloaded language with a precise canonical term.
3. Test relationships using concrete edge cases and boundary scenarios.
4. Compare claims with the code; surface contradictions for resolution.
5. As soon as a term resolves, update the applicable `CONTEXT.md` using [CONTEXT-FORMAT.md](CONTEXT-FORMAT.md). Keep implementation details and decisions out of the glossary.
6. When a durable decision emerges, consult [ADR-FORMAT.md](ADR-FORMAT.md). That reference is authoritative for whether the decision earns an ADR, where it belongs, and its format; skip the ADR when its gate does not pass.

Do not batch resolved language until the end. Completion means every term resolved in the session is captured in the applicable glossary, every code/model contradiction is resolved or explicitly open, and every qualifying durable decision is recorded once.
