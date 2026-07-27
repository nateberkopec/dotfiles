---
name: skill-creator
description: Create or update an agent skill. Use when defining triggers, workflows, references, scripts, or assets for a reusable skill.
license: Complete terms in LICENSE.txt
---

# Skill creator

## Understand

Establish concrete requests that should invoke the skill and what successful behavior looks like. For an existing skill, inspect observed failures or wasted work before editing. Include only knowledge or constraints that change the model’s default behavior.

## Plan

Identify universal steps, branch-specific reference knowledge, deterministic operations, and output assets. When deciding package layout, read [references/anatomy.md](references/anatomy.md). Keep each rule in one source of truth and give every reference a conditional pointer.

## Create

For a new skill, run:

```sh
python ~/.claude/skills/skill-creator/scripts/init_skill.py <skill-name> --path <parent-directory>
```

Replace every placeholder and delete unused example resources. For an update, edit the existing package directly instead.

Write `SKILL.md` as concise verb-first instructions. Put invocation triggers in the description. Keep mandatory steps, safety constraints, branch selection, and completion criteria inline; disclose optional detail through references. Convert fixed pipelines into tested scripts.

## Validate and package

```sh
python ~/.claude/skills/skill-creator/scripts/quick_validate.py <skill-directory>
python ~/.claude/skills/skill-creator/scripts/package_skill.py <skill-directory>
```

Fix every validation error. Exercise deterministic scripts with representative valid and invalid inputs. Use the skill on a real request, compare its behavior with the promised completion criteria, and prune no-op or duplicated instructions before considering it complete.
