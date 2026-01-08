---
name: ralphing
description: This skill should be used when setting up or running the Ralph autonomous coding loop that iterates through stories, runs tests, commits, and logs learnings.
---

# Ralphing

Ralph is an autonomous AI coding loop that ships features while you sleep. Each iteration runs in a fresh context window, while memory persists through git history and text files.

## When to Use

When the user wants to implement a multi-story feature autonomously, or mentions "ralph", "ralphing", or "autonomous loop".

## Workflow

### Step 1: Get the PRD

The user provides a PRD file, or you help them create one. Ask:
1. Do you have a PRD already, or should we create one together?
2. What's the repo path?
3. What's the test command? (e.g., `bundle exec rake`, `npm test`)
4. How many iterations max? (default: 25)

### PRD Format

```markdown
# PRD

Branch: `<branch-name>`

## Stories

### US-001: <Story title>

- [ ] <Acceptance criterion>
- [ ] <Acceptance criterion>

### US-002: <Story title>

- [ ] <Acceptance criterion>
```

Guidelines for stories:
- **Small**: Must fit in one context window
- **Explicit criteria**: Avoid vague ("Users can log in"), prefer specific checks
- Story order = priority (first = highest)

### Step 2: Start the Loop

```bash
~/.codex/skills/ralphing/assets/ralph.sh <repo_path> /tmp/ralph/<uuid>/prd.md [max_iterations] [test_cmd]
```

## How the Loop Works

1. Copies PRD and generates prompt with session paths
2. Checks out the branch specified in PRD
3. Loops: agent implements story → commits → runs tests
4. If tests fail, reverts commit and retries (progress.txt preserved)
5. Exits when agent signals `<promise>COMPLETE</promise>`

## Resources

- `assets/ralph.sh` - the loop script
- `assets/prompt.md` - prompt template (uses `<RALPH_DIR>` placeholder)
