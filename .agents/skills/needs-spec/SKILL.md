---
name: needs-spec
description: Work through this repository's need-spec issue queue and clarify specifications with the user.
---

Treat `need-spec` as a queue of issues whose requirements are incomplete. Use `gh` to fetch all open issues with that label and process them oldest first by creation date. For each issue, read its body and comments, explain what appears to need doing, and use the `grilling` skill to question the user about scope, behavior, and acceptance criteria, one question at a time. Once the user agrees to the resulting spec, add it to the issue body while preserving existing context, then remove `need-spec` and move to the next issue.
