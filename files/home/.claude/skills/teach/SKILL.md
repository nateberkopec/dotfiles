---
name: teach
description: Teach the user a new skill or concept within a persistent workspace.
license: "MIT; copyright Matt Pocock; see ../matt-pocock-skills-LICENSE.txt"
source: https://github.com/mattpocock/skills/tree/main/skills/productivity/teach
disable-model-invocation: true
argument-hint: "What would you like to learn about?"
---

# Teach

Treat the current directory as a persistent teaching workspace. Ground every lesson in the learner’s mission, current knowledge, preferences, and prior learning records. Prefer high-trust external sources over parametric recall.

## Load state

Read `MISSION.md`, `RESOURCES.md`, `NOTES.md`, existing `learning-records/`, reusable `assets/`, and relevant reference documents. Create missing state lazily.

Load a format only when creating or updating that artifact:

- [MISSION-FORMAT.md](MISSION-FORMAT.md) for `MISSION.md` and mission changes.
- [RESOURCES-FORMAT.md](RESOURCES-FORMAT.md) when curating sources.
- [LEARNING-RECORD-FORMAT.md](LEARNING-RECORD-FORMAT.md) after a non-obvious lesson or mission change.
- [GLOSSARY-FORMAT.md](GLOSSARY-FORMAT.md) when the topic develops canonical terminology.

These references are authoritative for document shapes; do not recreate their templates in the skill body.

## Teaching loop

1. Clarify the learner’s real-world mission if it is missing. Confirm before changing an established mission.
2. Estimate the zone of proximal development from the mission and learning records. Choose one tightly scoped skill that is challenging but achievable.
3. Gather only the trusted knowledge required for that skill. Add useful sources to `RESOURCES.md` and cite them in the lesson.
4. Create one short, self-contained HTML lesson under `lessons/`, using the next numbered dash-case filename. Reuse components from `assets/`; create a reusable component rather than duplicating lesson code.
5. Teach prerequisite knowledge plainly, then require practice through a tight feedback loop. Use retrieval, spacing, and interleaving when they improve long-term storage rather than momentary fluency.
6. Link relevant lessons and reference documents, recommend a primary source, and invite follow-up questions. Open the lesson for the user when possible.
7. Record durable learning, preferences, and newly canonical terminology in the appropriate workspace artifacts.

For skill practice, desirable difficulty builds retention; for initial knowledge acquisition, minimize incidental difficulty. For questions requiring lived judgment, answer what evidence supports and recommend a reputable practitioner community when appropriate, respecting a preference not to join one.

Completion means the learner gets one tangible mission-linked win, practices with feedback, can revisit a usable lesson, and the workspace state accurately supports the next session.
