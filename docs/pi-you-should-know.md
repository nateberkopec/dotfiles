# You should know (Pi)

A quiet, independent observer inspired by Claude Code's
`cc-plugin-you-should-know@builtin`. It watches assistant output and recent tool
results, then displays one consequential, easily missed issue above the editor.
It does not give the main agent advice, approve tools, or execute anything.

## Use

The dotfiles install `files/home/.pi/agent/extensions/you-should-know.ts` in Pi's
personal extensions directory. It is **off by default**, including in child
sessions. Enable it separately in each conversation:

```text
/you-should-know on
/you-should-know status
/you-should-know dismiss
/you-should-know off
```

Enablement and the latest note follow the active session branch and survive
resume/reload. `dismiss` clears the note; `off` hides it and cancels the observer.
To try the checkout without installing or converging the machine (fish):

```fish
pi -e files/home/.pi/agent/extensions/you-should-know.ts
```

## Behavior, privacy, and cost

- Uses the session's selected model via Pi's configured model registry and
  provider authentication. Provider-level guards still apply. No separate
  provider, account, telemetry, or credentials are configured.
- Sends up to the last 24,000 characters of user/assistant text and tool-result
  text to that provider. Thinking, images, and tool-call argument blocks are
  excluded. Transcript text is not a secret-redaction boundary.
- Reviews finalized assistant messages in the background, at most once per
  30 seconds during a run. A final check catches output produced while a review
  was in flight. Tool execution does not wait for intermediate reviews; run
  completion waits for the final review (bounded by a 30-second timeout).
- The observer has no tools. Its system prompt treats the transcript as
  untrusted data, asks for evidence-grounded warnings, and suppresses generic
  tips, summaries, already-explained issues, and repeated notes.
- `NONE` stays silent. Notes are bounded to 600 characters, stripped of terminal
  controls, and rendered with Pi's above-editor widget in regular/fullscreen
  TUI mode. In headless sessions, inspect the persisted custom entries instead.
- Makes additional billable requests (512-token output cap, low reasoning,
  no provider retries). Usage is saved in `you-should-know-review` entries;
  these calls are not included in Pi's main-agent usage display. Notes are
  saved as `you-should-know-note` custom entries, **not model-context messages**.
- Off, dismiss, session-tree navigation, reload, and shutdown cancel stale work.

This is a behavioral reimplementation, not an exact source port. The
[official Claude Code mods overview](https://code.claude.com/docs/en/plugins/mods/overview)
describes a side agent watching longer tasks and displaying a note above the
prompt, disabled by default. Its public-source list does not include this mod.
Research used Exa search and page extraction through server-1.

## Verification

```fish
node --test test/you_should_know_test.mjs test/you_should_know_sessions_test.mjs
bash tools/typecheck_pi_extensions.sh
```

The session regression suite launches the **real Pi CLI**, loads the production
extension, and uses a network-free test provider. It checks default-off, risk,
quiet output, exactly one review of a finalized response, no observer messages in
main context, actual process restart/resume, dismissal, and disabling. Unit
regressions cover background cancellation, coalescing, limits, provider errors,
branch restoration, and headless persistence. Both suites run in CI.

Local verification on Pi 0.99.2 (2026-10-04), before opening the PR:

- All 21 tests in the CI Pi-extension command passed; extension typecheck passed.
- A real OpenAI `gpt-6.1-sol` session, with the existing datasafe extension loaded,
  repeated a fictional runbook that deleted production data before verifying a
  backup and declared success without tests. The independent observer returned:

  > The runbook deletes the production database before verifying that the backup
  > is restorable, risking irreversible data loss if followed. It also marks the
  > migration successful without tests, so that status would be unverified.

- A separate real-model `2 + 2` session completed its review without a note.
- The live-model risk session was reopened in actual pseudo-terminal Pi
  sessions. The saved note rendered above the editor in regular mode at 100
  columns and fullscreen mode at 48 columns.
- Local evidence: `/tmp/ysk-live-{risk,quiet}.jsonl`, corresponding `.events.jsonl`
  files, and `/tmp/ysk-{regular,fullscreen}.capture`. These are local test artifacts,
  not installed files or committed transcripts.

These tests demonstrate lifecycle, UI integration, and useful live-model behavior.
They cannot guarantee that a probabilistic observer will catch every issue or
never produce a false positive. It is an advisory aid, not a safety gate.
