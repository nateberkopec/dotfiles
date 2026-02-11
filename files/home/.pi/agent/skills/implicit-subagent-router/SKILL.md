---
name: implicit-subagent-router
description: Use this skill to decide when subagents are worth it: delegate complex multi-step work, independent tasks that can run in parallel, context-heavy investigations that benefit from isolation, or tasks needing specialist tools/personas. Keep tiny 1-2 step requests in the main agent.
---

# Implicit Subagent Router

Apply this policy whenever the `subagent` tool is available and delegation would improve quality, speed, or context hygiene.

## Intent

Operate as a router-first orchestrator:

- Prefer delegating medium/large tasks to subagents.
- Reuse existing agents when possible.
- Create project-scoped temporary agents on the fly when needed.
- Remove temporary agents after completion unless the user asks to keep them.

## Fast Delegation Heuristic

Delegate by default unless the task is tiny.

Run in the main agent only when all are true:

1. Task is <10 minutes and <=2 concrete steps.
2. No parallelizable subtasks.
3. No major context gathering required.
4. No specialized persona/tooling needed.

Otherwise delegate with `subagent`.

## Router Workflow

### 1) Discover available agents/chains

Call:

```json
{ "action": "list" }
```

Use `agentScope: "both"` when working in a repo with project agents; prefer project definitions when names collide.

### 2) Pick execution shape

- **Single** `{ agent, task }`: one focused job.
- **Chain** `{ chain:[...] }`: staged workflows (scout -> planner -> implementer -> reviewer).
- **Parallel** `{ tasks:[...] }`: independent shards (files/modules/domains).

Use chain variables where useful: `{task}`, `{previous}`, `{chain_dir}`.

### 3) Match existing agents first

Select the closest-fit agent by description + tools + model profile.

If no good match exists, create a temporary agent.

### 4) Create temporary agent (project scope)

Call `create` with minimal required tools and a narrow prompt.

Naming policy (required):

- lowercase kebab-case
- prefix `tmp-`
- include domain + short suffix
- example: `tmp-auth-scout-a7f3`

Template:

```json
{
  "action": "create",
  "config": {
    "name": "tmp-<domain>-<suffix>",
    "description": "Temporary specialist for <goal>",
    "scope": "project",
    "model": "anthropic/claude-sonnet-4-5",
    "tools": "read, grep, find, bash",
    "systemPrompt": "You are a focused specialist for <goal>. Stay scoped, concise, and evidence-driven."
  }
}
```

Tooling defaults:

- Recon/analysis: `read, grep, find, ls`
- Implementation: `read, grep, find, bash, edit, write`
- External systems only when necessary (MCP entries must be explicit).

### 5) Execute

Use explicit task strings with output format expectations.

Recommended defaults for implicit mode:

- `clarify: false` (avoid blocking interactive TUI unless user asks)
- `artifacts: true`
- `maxOutput` tuned for readability on very large outputs

Examples:

```json
{ "agent": "tmp-auth-scout-a7f3", "task": "Map auth flow and list key files with 1-line rationale each.", "clarify": false }
```

```json
{
  "chain": [
    { "agent": "scout", "task": "Gather context for {task}", "output": "context.md" },
    { "agent": "planner", "task": "Create a plan from {previous}", "reads": ["context.md"] }
  ],
  "task": "refactor authentication middleware",
  "clarify": false
}
```

### 6) Cleanup temporary agents

After successful run, delete temporary agents unless user wants persistence.

```json
{ "action": "delete", "agent": "tmp-auth-scout-a7f3", "agentScope": "project" }
```

Keep agent only when:

- user requests persistence,
- workflow is clearly reusable,
- or repeated invocations are expected in this repo.

## Reliability Rules

- If unknown-agent error occurs, re-run `{ "action": "list" }`, pick a valid name, retry once.
- If temporary creation fails due to collision, regenerate suffix and retry.
- If a delegated step fails, report failure point, then either:
  - retry with tighter task, or
  - switch to a more suitable agent.

## Safety Rules

- Never delegate destructive operations without explicit user confirmation.
- Keep temp agents narrowly scoped; do not grant broad tool access by default.
- Prefer project-scoped temp agents over user-scoped for repo-specific work.
- Summarize delegated results and cite concrete evidence (files, commands, outputs).

## Output Contract (for router responses)

After delegation, always provide:

1. What was delegated (agent/mode).
2. Why that routing choice was made.
3. Key findings/results.
4. Any created/deleted temporary agent names.
5. Suggested next action.
