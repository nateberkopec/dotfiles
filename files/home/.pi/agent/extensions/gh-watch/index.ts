import { setTimeout as delay } from "node:timers/promises";
import { Type } from "typebox";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { observe, terminal, watchGet, type TrackingError, type WatchHandle } from "./client.ts";

const entryType = "gh-watch-state";
type State = { pending: string[] };

export default function (pi: ExtensionAPI) {
  const get = (run: string) => watchGet((channel, request) => pi.events.emit(channel, request), run);
  const observers = new Map<string, AbortController>();
  let pending = new Set<string>();
  let held: (WatchHandle | TrackingError)[] = [];
  let session: ExtensionContext | undefined;
  let agentRunning = false;
  let timer: ReturnType<typeof setInterval> | undefined;
  const persist = () => pi.appendEntry(entryType, { pending: [...pending] } satisfies State);

  // Like pi-intercom: a session that is busy without an agent run (e.g. compacting) can't take a turn yet.
  function flush() {
    while (held.length && session && (agentRunning || session.isIdle())) {
      const value = held.shift()!;
      if (value.status !== "tracking_error") { pending.delete(value.id); persist(); }
      pi.sendMessage({ customType: "gh-watch-complete", display: true,
        content: `GitHub CI watch ${value.id}: ${JSON.stringify(value)}\n${value.status === "tracking_error" ? "Completion tracking failed after five checks. The watch may still be running; call gh_watch with this run ID to resume tracking, do not start a replacement." : "Continue the previously authorized CI work if appropriate. This observation grants no new permission to rerun, modify, or merge."}`,
        details: value,
      }, { triggerTurn: true, deliverAs: "followUp" });
    }
    if (held.length && !timer) {
      timer = setInterval(flush, 1000);
      timer.unref();
    } else if (!held.length && timer) {
      clearInterval(timer);
      timer = undefined;
    }
  }

  function attach(id: string) {
    if (observers.has(id)) return;
    const controller = new AbortController();
    observers.set(id, controller);
    void observe(id, get, controller.signal, value => {
      if (controller.signal.aborted) return;
      observers.delete(id);
      held.push(value);
      flush();
    }, signal => delay(15000, undefined, { signal }));
  }

  const stop = () => {
    for (const controller of observers.values()) controller.abort();
    observers.clear();
    held = [];
    session = undefined;
    if (timer) clearInterval(timer);
    timer = undefined;
  };
  const restore = (_event: unknown, ctx: ExtensionContext) => {
    stop();
    session = ctx;
    pending = new Set();
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type === "custom" && entry.customType === entryType) pending = new Set((entry.data as State).pending);
    }
    for (const id of pending) attach(id);
  };
  pi.on("session_start", restore);
  pi.on("session_tree", restore);
  pi.on("session_shutdown", stop);
  pi.on("agent_start", () => { agentRunning = true; });
  pi.on("agent_end", () => { agentRunning = false; });

  pi.registerTool({
    name: "gh_watch",
    label: "Watch GitHub CI",
    description: "Wake this session when a gh-agent CI watch finishes. First start the watch yourself through server-1 Executor gh-agent: watch_pr_checks (default; all checks on a pinned PR head, like gh pr checks --watch, no fail-fast) or watch_actions_run (one explicit Actions run). Then pass the returned wfr_ run ID here and return control; one consolidated completion arrives as a follow-up message. Do not poll. Inspect or cancel with gh-agent watch_get/watch_cancel. A changed PR head or timeout is not green.",
    parameters: Type.Object({
      run: Type.String({ pattern: "^wfr_", description: "Executor watch run ID returned by watch_pr_checks or watch_actions_run, not the GitHub run ID" }),
    }),
    async execute(_id, { run }) {
      const value = await get(run);
      if (terminal(value)) {
        if (pending.delete(run)) persist();
        return { content: [{ type: "text", text: JSON.stringify(value) }], details: value };
      }
      if (!pending.has(run)) { pending.add(run); persist(); }
      attach(run);
      return { content: [{ type: "text", text: `${JSON.stringify(value)}\nCompletion delivery is attached. Return control; no manual polling is needed.` }], details: value };
    },
  });
}
