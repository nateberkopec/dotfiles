---
description: Follow an existing Markdown plan without waiting for unnecessary approval
argument-hint: "<FILE>"
---

Follow the existing plan at `$@`. Read it before doing any work. Do not replace its objectives or assume the checklist is ordered. Its top-level actionable items must use Markdown checkboxes (`- [ ]` / `- [x]`); other prose is fine. An unfinished item may end with `<!-- active -->` or `<!-- blocked: specific reason -->`. Keep at most one active item. Add those markers as needed, without rewriting the plan unnecessarily.

Choose any useful, unblocked work you can do now without human input. Mark it active, work on it, verify it, then mark it done. If it cannot proceed, replace the active marker with a specific blocked reason; if other useful items remain, work on those instead. Treat external prerequisites and dependencies as blockers too, not just questions for the user.

Do not stop merely because an item is done. Before ending, reread the plan and look for *any* remaining useful, unblocked work. Continue in this same run when possible. Ask me only for a decision or permission you genuinely need, and make the question explicit in the plan. When nothing actionable remains, summarize what was done and what is blocked. If the plan is ambiguous or cannot be read, stop and tell me rather than guessing.
