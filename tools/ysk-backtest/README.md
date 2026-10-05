# YSK backtest reviewer

A local, read-only browser utility for reviewing recorded warnings or replaying the current YSK policy against any Pi session JSONL file.

From the dotfiles checkout, in Fish:

```fish
node tools/ysk-backtest/server.mjs /absolute/path/to/session.jsonl
```

The command starts a loopback-only server on an available port and opens its private URL in your browser. Stop it with Ctrl+C. Use `--no-open` to print the URL without opening a browser, `--port 4317` for a fixed port, or `--leaf ENTRY_ID` to review another branch. The default is the branch ending at the last entry in the file. You can also upload another session through **Open session**.

## Reviewing

- **Recorded warnings** shows existing YSK notes without making any inference calls. Saved original snapshots are used when available; older notes show a clearly labeled reconstruction.
- **Run replay** requires explicit confirmation. It sends historical text to pinned Jev and Luna through the current production observer code and your configured credentials. Provider charges apply. Pi and its SDK must be installed; `TYPESAFE_API_KEY` and Luna authentication must be available. Datasafe provider restrictions still apply.
- The confidence threshold defaults to 85%. A warning requires Jev's `warn` choice, a non-`none` category, and sufficient confidence. Luna can still return `NONE`.
- Warnings appear while replay progresses. Use **Previous**, **Next**, numbered warning buttons, or left/right arrow keys to browse. The right pane shows the snapshot associated with that warning. Stop replay at any point; already generated warnings remain viewable.
- There are no rating controls, result files, browser storage, or session writes. Results and history live only in server memory. Reloading the page keeps the current in-memory run; restarting the server loses it.

## Replay semantics and limitations

Replay follows a selected entry-tree branch and evaluates assistant checkpoints in chronological order. It includes only prior user/assistant/tool-result text, excludes thinking and images, and bounds snapshots to the same last 24,000 characters used by production YSK. Like production's raw-branch snapshot, this is not Pi's compacted model context.

Intermediate assistant checkpoints approximate the 30-second throttle using recorded timestamps. Final responses are always eligible; unchanged snapshots are skipped. This is a deterministic replay, not an exact recreation of asynchronous production scheduling: historical overlapping observer calls, cancellation, and final-check timing are not recoverable from a session file. Historical observer on/off state does not disable the replay.

The replay builds its own last-50 offered-topic history, including normalized duplicate suppression. It does not inject original YSK notes into that history and does not assume the user would have understood a newly generated warning based on acknowledgments of different historical warnings. Its explicit-understanding history therefore starts and remains empty. Main-conversation demonstrations of understanding are still visible in the transcript.

Only displayed warnings are browsable in this first version; a quiet replay is not evidence that the session had no missed issues. Model behavior can vary between runs. A timeout or provider error stops the run without retries and is shown in the page.

Session content remains sensitive. The server binds only to `127.0.0.1`, requires a random access token for session APIs, rejects foreign Host/Origin headers, renders text rather than session HTML, and disables HTTP caching. Do not share the private URL or expose the port through a tunnel.

## Tests

```fish
node --test test/ysk_backtest_test.mjs
```
