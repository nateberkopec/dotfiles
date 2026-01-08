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

Note: Ralph is typically run in a git worktree. If already on the correct branch (or detached HEAD), the branch checkout is skipped.

### Step 2: Start the Loop

```bash
~/.claude/skills/ralphing/assets/ralph.sh start <repo_path> <prd.md> [max_iterations] [test_cmd]
```

This returns a session directory (e.g., `/tmp/ralph/ABC123-...`) and runs the loop in the background.

### Step 3: Monitor Progress

Poll the session status periodically:

```bash
~/.claude/skills/ralphing/assets/ralph.sh status <ralph_dir>
```

This outputs:
- `status`: `running`, `complete`, or `failed`
- `iteration`: current/max iterations
- Full contents of `progress.txt`

Keep polling until status is `complete` or `failed`.

## How the Loop Works

1. `start` copies PRD, generates prompt, checks out branch (if needed), and spawns background process
2. Background loop: agent implements story -> commits -> runs tests
3. If tests fail, reverts commit and retries (progress.txt preserved)
4. Exits when agent signals `<promise>COMPLETE</promise>` or max iterations reached
5. Parent agent polls `status` to observe progress without blocking

## Resources

- `assets/ralph.sh` - the loop script (start/status commands)
- `assets/prompt.md` - prompt template (uses `<RALPH_DIR>` placeholder)
