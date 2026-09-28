---
name: fix-upstream
description: Reproduce, report, and work around bugs in upstream software managed by these dotfiles. Use when a managed dependency is broken, an upstream fix is needed, or dotfiles must temporarily use a patched fork.
---

# Fix upstream

Deliver a runnable upstream bug report, an open dotfiles tracking issue labeled `blocked`, and a dotfiles PR that installs a fixed fork. Keep the fork in place until a verified upstream release replaces it.

## GitHub communication

Begin every GitHub message with this blockquote, followed by a blank line. Name the model that actually wrote it:

```markdown
> This was written by an agent. Model: <model ID>.
```

Apply it to issue and PR bodies, comments, reviews, discussion posts, release notes, and other prose published on GitHub. Preserve or refresh it when editing a message. Read the model ID from the current runtime (for Pi, `PI_MODEL`); do not guess it or copy an earlier agent's identity.

## 1. Reproduce locally

Identify the installed version, upstream repository, and dotfiles install and lock configuration. Read the upstream contribution instructions. Keep checkouts, scripts, and private diagnostic evidence under this repository's `./tmp`.

Use `gh` to search the upstream repository's open and closed issues, pull requests, and discussions for the symptom, relevant code, and likely cause. Read the relevant threads, linked changes, and commit history before proposing a fix or posting a report. Check dotfiles history for earlier workarounds too. Record useful links and any search surface that is unavailable. Prior reports may explain a deliberate behavior, a rejected fix, or a regression.

Build the smallest runnable script that demonstrates the observed bug. Run it against the affected version and record the expected and actual results. Match the real failing event or request shape; a fixture that passes does not rule out a failure it never exercised.

The public reproduction must work without private repositories, local paths, account data, or prior conversation context. Include prerequisites, exact versions, setup commands, the complete script, its invocation, and relevant output. Use synthetic inputs where possible. State any required credentials without publishing them.

You may attempt a fix before reporting, but a working fix is not a prerequisite for opening the upstream issue.

## 2. Open the upstream issue

Use the history search above to avoid duplicate reports. If the same bug already has an issue, add the runnable evidence there and use that URL throughout this workflow.

Write plain, simplified technical English at an 11th-grade reading level or lower. Use short sentences and concrete terms. Assume only familiarity with the upstream project. Explain the affected behavior and impact without references to "our setup" or this conversation.

Include:

- A title naming the broken behavior.
- A brief description, affected version, and relevant environment.
- Expected and actual behavior.
- The complete minimal runnable reproduction and observed output.
- A proposed fix, if tested, clearly separated from facts and open questions.

Put a long reproduction inside `<details><summary>Runnable reproduction</summary>...</details>`. Keep the prerequisites and run command easy to find. A local file path, trace, screenshot, or link to a private script is not a runnable example.

Done when the report is published and its reproduction has actually been run.

## 3. Track the bug in dotfiles

Open a dotfiles issue explaining the bug, its impact here, and the upstream issue URL. Apply the `blocked` label. The issue tracks the upstream dependency that must be resolved before removing the workaround.

Record the managed tool, fork, patch reference, and conditions for returning upstream. Update these fields as the next step supplies them. Keep this issue open while dotfiles uses the fork. Link it from the dotfiles PR with `Refs #N`, rather than closing the tracking issue when the workaround merges.

## 4. Fix and pin a fork

Create a fork under the user's GitHub account, or reuse an existing fork of the same upstream. Keep the patch small and add a regression test at the failing boundary. Show the reproduction fail on the affected code and pass on the patch. Run the upstream project's required checks; report any missing or failing checks honestly.

Publish an installable fork artifact or commit. Verify installation from the same source that dotfiles will use, including required build output and runtime dependencies. A source fork that cannot run through the managed installer is not a completed workaround.

In a dotfiles feature branch, switch the dependency to that fork using an immutable commit, version, or checksum. Update the required lock entries and any related assertions. Preserve supported platforms and the usual convergence path. Record the upstream and tracking issue URLs beside the override where the configuration format permits, so a routine update does not erase the reason for the fork.

If no verified fix or installable artifact can be produced, leave both issues open and report the exact blocker. Do not point dotfiles at a speculative fix.

## 5. Open the dotfiles PR

The PR must explain the bug, link both issues, identify the fork and immutable pin, list the checks run, and state how to remove the workaround. Keep unrelated upgrades out of the patch. Follow the repository's CI and merge rules; opening the PR does not authorize converging the live machine.

Report the upstream issue, `blocked` dotfiles issue, fork, dotfiles PR, validation results, and any remaining gaps.

When upstream ships a fix, verify the original reproduction against that release, switch dotfiles back through a PR, remove the fork-specific configuration, and close the tracking issue only after the replacement is shipped.
