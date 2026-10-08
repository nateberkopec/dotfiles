# YSK warnings

YSK independently watches for consequential, unacknowledged mistakes while Pi works. Jev gates a tool-less Luna review; the footer accounts for both models. A warning label such as `YSK (99%|SEC):` shows Jev's confidence and category, not a guarantee that the warning is correct.

## Warning card

Warnings stay pending until you explicitly acknowledge them. A quiet review, `NONE` response, or a later warning does not clear an existing warning. The passive card shows at most two text lines plus a count of additional pending warnings. It never takes keyboard focus automatically.

Press **Ctrl+;** to review the card. This shortcut is also listed in `/hotkeys`.

| Key | Action |
| --- | --- |
| Left / right | Select `(A)cknowledge`, `(D)etails`, or `(B)ack to editor` |
| Enter | Activate the selected action |
| A / D / B | Activate that action directly (uppercase or lowercase) |
| Tab / Shift+Tab | Next / previous warning, wrapping around |
| Up / down | Scroll a long warning |
| Esc / Ctrl+; | Return to your draft without acknowledging |

Acknowledging removes only the selected warning and reveals another. Acknowledging the last warning returns to the editor automatically. Pi preserves your draft throughout card review.

Details opens the existing Luna side chat, using that warning's original text-only evidence snapshot. It does not silently switch to the latest transcript. You can ask follow-up questions there; those calls are accounted in the footer. The warning remains pending when you close the chat. Nothing is sent to the main agent unless you explicitly use `/ysk-inject`.

## Seen versus understood

Acknowledgment means **seen**, not **understood**, **fixed**, or **safe to proceed**. `/ysk-understood` separately records explicit understanding and acknowledges the selected warning. Previously offered topics already suppress repeat warnings; understood history remains a distinct, stronger instruction to the observer.

Command fallbacks remain available: `/ysk-inbox` reviews the card, `/ysk-dismiss` acknowledges the selected warning without asserting understanding, and `/ysk-chat` opens its side chat.

## Persistence

Pending warnings, original snapshots, metadata, and per-warning acknowledgments survive reload and session resume. They follow the active session branch; a tree navigation restores that branch's warning state. Money spent on all branches remains accounted in the footer.

`/ysk-demo off` hides the card and stops observation without deleting pending warnings. `/ysk-demo on` reveals them again.

## Confidence control

The global warn-confidence default comes from `YSK_CONFIDENCE_THRESHOLD`, a number from 0 to 1. If unset, it is 0.85. Invalid values produce a warning and fall back to 0.85.

To persist a lower default across projects and new Pi sessions, run this in Fish:

```fish
set -Ux YSK_CONFIDENCE_THRESHOLD 0.5
```

Restart Pi to pick up the changed environment. To remove the global override:

```fish
set -eU YSK_CONFIDENCE_THRESHOLD
```

`/ysk-demo 0.5` sets a session-branch override that survives reload and resume. `/ysk-demo default` clears that override and uses the global default again. Turning observation on or off does not create a confidence override. Existing sessions with previously saved numeric thresholds keep those values until you use `/ysk-demo default`.

This is confidence in Jev's selected answer, not `P(warn)`. Setting it to `0` removes only the confidence filter: Jev must still choose `warn` and a non-`none` category before Luna reviews the transcript, and Luna may still return `NONE`.

Historical sessions used replaceable note snapshots. Migration preserves their last visible warning and its own recorded metadata; it does not resurrect warnings already cleared by the old implementation. Newly recorded warnings use an additive queue with explicit acknowledgments.
