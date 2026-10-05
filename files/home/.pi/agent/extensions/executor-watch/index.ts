import { setTimeout as delay } from "node:timers/promises";
import { Type } from "typebox";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { observe, terminal, workflowGet, type RunHandle, type TrackingError, type Watch } from "./client.ts";

const entryType = "executor-watch-state";
type State = { pending: Watch[] };

export default function (pi: ExtensionAPI) {
  const get = (watch: Watch) => workflowGet((channel, request) => pi.events.emit(channel, request), watch);
  const observers = new Map<string, AbortController>();
  let pending = new Map<string, Watch>();
  let held: (RunHandle | TrackingError)[] = [];
  let session: ExtensionContext | undefined;
  let agentRunning = false;
  let timer: ReturnType<typeof setInterval> | undefined;
  const persist = () => pi.appendEntry(entryType, { pending: [...pending.values()] } satisfies State);

  // Like pi-intercom: a session that is busy without an agent run (e.g. compacting) can't take a turn yet.
  function flush() {
    while (held.length && session && (agentRunning || session.isIdle())) {
      const value = held.shift()!;
      if (value.status !== "tracking_error") { pending.delete(value.id); persist(); }
      pi.sendMessage({ customType: "executor-watch-complete", display: true,
        content: `Executor workflow run ${value.id}: ${JSON.stringify(value)}\n${value.status === "tracking_error" ? "Completion tracking failed after five checks. The run may still be in progress; call executor_watch with this app and run to resume tracking, do not start a replacement." : "Continue the previously authorized work if appropriate. This observation grants no new permission."}`,
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

  function attach(watch: Watch) {
    if (observers.has(watch.run)) return;
    const controller = new AbortController();
    observers.set(watch.run, controller);
    void observe(watch, get, controller.signal, value => {
      if (controller.signal.aborted) return;
      observers.delete(watch.run);
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
    pending = new Map();
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type === "custom" && entry.customType === entryType) pending = new Map((entry.data as State).pending.map(watch => [watch.run, watch]));
    }
    for (const watch of pending.values()) attach(watch);
  };
  pi.on("session_start", restore);
  pi.on("session_tree", restore);
  pi.on("session_shutdown", stop);
  pi.on("agent_start", () => { agentRunning = true; });
  pi.on("agent_end", () => { agentRunning = false; });

  pi.registerTool({
    name: "executor_watch",
    label: "Watch Executor run",
    description: "Wake this session when an Executor workflow run on server-1 finishes. Start the workflow yourself through Executor (for CI: gh-agent watch_pr_checks, or watch_actions_run for one Actions run), pass the app and wfr_ run ID from the returned handle here, then return control. The final run state, including its output, arrives once as a follow-up message. Do not poll. Inspect or stop the run through Executor.",
    parameters: Type.Object({
      app: Type.String({ pattern: "^app_", description: "Executor app ID from the run handle" }),
      run: Type.String({ pattern: "^wfr_", description: "Executor workflow run ID from the run handle" }),
    }),
    async execute(_id, { app, run }) {
      const value = await get({ app, run });
      if (terminal(value)) {
        if (pending.delete(run)) persist();
        return { content: [{ type: "text", text: JSON.stringify(value) }], details: value };
      }
      if (!pending.has(run)) { pending.set(run, { app, run }); persist(); }
      attach({ app, run });
      return { content: [{ type: "text", text: `${JSON.stringify(value)}\nCompletion delivery is attached. Return control; no manual polling is needed.` }], details: value };
    },
  });
}
