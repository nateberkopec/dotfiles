---
name: fix-upstream
description: Reproduce, report, and work around bugs in upstream software managed by these dotfiles. Use when a managed dependency is broken, an upstream fix is needed, or dotfiles must temporarily use a patched fork.
---

# Fix upstream

## Goal and authority

Restore reliable behavior in dotfiles when an upstream dependency is broken, and make returning to upstream straightforward. Use your judgment and initiative to carry the work through to completion within the boundaries below. Choose the implementation and sequence of work yourself.

You may merge the dotfiles PR after required checks pass. If completing the goal requires crossing a boundary, ask the user for that specific decision.

## Boundaries

- **Scope:** Change only what is necessary to make the bug go away. Support the platforms these dotfiles currently support; do not expand that set to match upstream's platforms.
- **Release:** Publish a clearly identified fork as a patch-version increment of the release currently used by dotfiles. Base it on that release, not upstream main or a newer release. Preserve runtime dependency versions unless changing them is necessary to fix the bug.
- **Communication:** The only authorized contact with anyone other than the user is the initial upstream bug report described below. No follow-up comments, replies, upstream PRs, or other outreach without permission. Creating and maintaining the user's fork, release records, dotfiles tracking issue, and dotfiles PR are authorized deliverables, not permission to start conversations with others.
- **Privacy:** Public reports and artifacts must exclude credentials, private prompts, private code, and identifying diagnostic data. Use a self-contained synthetic reproduction; keep private evidence and scratch work under this repository's `./tmp`.
- **Automation:** Forks must not introduce scheduled automation. Inherited scheduled workflows must remain disabled or have their schedule triggers removed before being enabled.
- **Live machine:** Merging is authorized; running `dotf run` or otherwise converging the user's main machine requires separate authorization.

## Upstream report

Account for relevant upstream and dotfiles history before reporting: open and closed issues, PRs, discussions, and relevant commits. Avoid a duplicate issue; if the bug is already reported, publish the initial reproduction there instead. This does not authorize subsequent comments.

Write plain technical English at an 11th-grade reading level or lower. Include the affected version, expected and actual behavior, and a complete minimal reproduction that has actually been run: prerequisites, setup, script, invocation, and observed output. Readers must not need private files or this conversation. Put long code inside `<details><summary>Runnable reproduction</summary>...</details>`.

A tested proposed fix may be included in the initial report, but a working fix is not a prerequisite for reporting the bug.

## Completion

The work is complete when:

- The runnable upstream report is published.
- A verified fork release is pinned immutably through a merged dotfiles PR, with the required locks and supported platforms covered. The original reproduction fails before the fix and passes after it, and installation through the managed installer has been verified.
- An open dotfiles issue labeled `blocked` links the upstream report, fork release, patch reference, and dotfiles PR, and states the conditions for returning upstream. Link it with `Refs #N`; merging the workaround must not close it.
- The user has the result, verification evidence, and any remaining limitations. If completion is blocked, report the specific blocker rather than treating an unverified workaround as finished.

When an upstream fix becomes available, verify it against the original reproduction and replace the fork through a dotfiles PR. Close the tracking issue only after that replacement ships.

## GitHub disclosure

Begin every authorized GitHub message with this blockquote, followed by a blank line:

```markdown
> This was written by an agent. Model: <model ID>.
```

Use the actual writing model's runtime ID (`PI_MODEL` in Pi), including when editing a message. This applies to issue and PR bodies, release notes, and any other authorized GitHub prose; it grants no additional permission to communicate.
