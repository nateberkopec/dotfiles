# Ralph Agent Instructions

## Your Task

1. Read `<RALPH_DIR>/prd.md`
2. Read `<RALPH_DIR>/progress.txt`
3. Pick the first story with unchecked criteria
4. Implement that ONE story
5. Run typecheck and tests
6. Commit (always use `--no-gpg-sign`): `git commit --no-gpg-sign -m "feat: [ID] - [Title]"`
7. Update `<RALPH_DIR>/prd.md`: mark `[x]` for done
8. Append learnings to `<RALPH_DIR>/progress.txt`

## Progress Format

APPEND to `<RALPH_DIR>/progress.txt`:

## [Date] - [Story ID]
- What was implemented
- Files changed
- **Learnings:**
  - Patterns discovered
  - Gotchas encountered
---

## Stop Condition

After completing your story, reply:
<promise>COMPLETE</promise>
