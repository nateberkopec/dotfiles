# Skill package anatomy

A skill directory requires `SKILL.md` with YAML frontmatter containing one `name` and one `description`.

- `scripts/` holds deterministic executable helpers that would otherwise be rebuilt repeatedly. Test maintained scripts.
- `references/` holds detailed or branch-specific knowledge loaded only through an explicit “read when…” pointer.
- `assets/` holds templates, fonts, images, or boilerplate copied into output rather than loaded as instructions.

Keep universal procedure in `SKILL.md`. Put details needed by only one branch in a named reference. Keep each fact in one place. Delete placeholder resources the skill does not use.

Names are 1–40 characters: lowercase alphanumeric segments separated by single hyphens. The frontmatter name must exactly match the directory.
