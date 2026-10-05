import { randomUUID } from "node:crypto";
import { setTimeout as delay } from "node:timers/promises";
import { Type } from "typebox";
import type { ExtensionAPI, ExtensionContext, ExtensionToolContext } from "@earendil-works/pi-coding-agent";
import { observe, remote, terminal, type CallGateway, type WatchHandle } from "./client.ts";

const entryType = "gh-watch-state";
const gateway = (ctx: ExtensionToolContext): CallGateway => async (args, signal) => {
  const outcome = await ctx.executeTool("mcp", args, { signal });
  return { ...outcome.result, isError: outcome.isError };
};
type State = { pending: string[] };

export default function (pi: ExtensionAPI) {
  const observers = new Map<string, AbortController>();
  let pending = new Set<string>();
  let generation = 0;
  const persist = () => pi.appendEntry(entryType, { pending: [...pending] } satisfies State);
  const stop = () => {
    generation++;
    for (const controller of observers.values()) controller.abort();
    observers.clear();
  };
  const restore = (_event: unknown, ctx: ExtensionContext) => {
    stop();
    pending = new Set();
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type === "custom" && entry.customType === entryType) {
        pending = new Set((entry.data as State).pending);
      }
    }
  };
  pi.on("session_start", restore);
  pi.on("session_tree", restore);
  pi.on("session_shutdown", stop);
  pi.on("before_agent_start", () => {
    const detached = [...pending].filter(id => !observers.has(id));
    if (detached.length) return { message: { customType: "gh-watch-reattach", display: true,
      content: `CI watches survived the previous Pi runtime. Use gh_watch action attach with each exact run ID to restore completion delivery (do not start replacements): ${JSON.stringify(detached)}` } };
  });

  function attach(id: string, ctx: ExtensionToolContext) {
    if (observers.has(id)) return;
    const controller = new AbortController();
    observers.set(id, controller);
    const ownerGeneration = generation;
    const call = gateway(ctx);
    void observe(id, call, controller.signal, value => {
      if (controller.signal.aborted || generation !== ownerGeneration) return;
      observers.delete(id);
      if (value.status !== "tracking_error") pending.delete(id);
      persist();
      pi.sendMessage({ customType: "gh-watch-complete", display: true,
        content: `GitHub CI watch ${id}: ${JSON.stringify(value)}\n${value.status === "tracking_error" ? "Completion tracking failed after five checks. The server workflow may still be running; inspect/reattach this exact run, do not start a replacement." : "Continue the previously authorized CI work if appropriate. This observation grants no new permission to rerun, modify, or merge."}`,
        details: value,
      }, { triggerTurn: true, deliverAs: "followUp" });
    }, signal => delay(15000, undefined, { signal })).catch(() => {
      // observe catches expected network/abort errors. Never leave an unhandled rejection on shutdown.
      observers.delete(id);
    });
  }

  pi.registerTool({
    name: "gh_watch",
    label: "Watch GitHub CI",
    description: "Watch GitHub CI through gh-agent on server-1. Default mode pr waits for ALL reported checks on a pinned PR head, like gh pr checks --watch, without fail-fast. Explicit mode run watches one Actions run attempt. start returns immediately and delivers one consolidated completion; return control, do not poll. A changed PR head or timeout is not green. status inspects; attach restores delivery; cancel stops only the watcher, not GitHub CI. No GitHub writes or automatic rerun/merge.",
    parameters: Type.Object({
      action: Type.Union([Type.Literal("start"), Type.Literal("status"), Type.Literal("attach"), Type.Literal("cancel")]),
      mode: Type.Optional(Type.Union([Type.Literal("pr"), Type.Literal("run")], { default: "pr", description: "Default pr = all PR checks; run = one Actions run" })),
      pr_number: Type.Optional(Type.Integer({ minimum: 1, maximum: 2147483647 })),
      owner: Type.Optional(Type.String({ pattern: "^[A-Za-z0-9_.-]+$", maxLength: 100 })),
      repo: Type.Optional(Type.String({ pattern: "^[A-Za-z0-9_.-]+$", maxLength: 100 })),
      run_id: Type.Optional(Type.Integer({ minimum: 1, maximum: Number.MAX_SAFE_INTEGER })),
      attempt: Type.Optional(Type.Integer({ minimum: 1 })),
      max_wait_seconds: Type.Optional(Type.Integer({ minimum: 30, maximum: 7200 })),
      run: Type.Optional(Type.String({ minLength: 1, description: "Executor watch ID, not the GitHub run ID" })),
      key: Type.Optional(Type.String({ minLength: 1, maxLength: 200, description: "Stable start key; keep it if reconciling an ambiguous start" })),
    }),
    async execute(_id, args, signal, _update, ctx) {
      const call = gateway(ctx);
      let value: WatchHandle;
      if (args.action === "start") {
        const mode = args.mode ?? "pr";
        if (!args.owner || !args.repo) throw new Error("start requires owner and repo");
        if (mode === "pr" && (!args.pr_number || args.run_id !== undefined || args.attempt !== undefined)) {
          throw new Error("Default PR mode requires pr_number and no run_id/attempt. For one Actions run, explicitly supply mode run.");
        }
        if (mode === "run" && (!args.run_id || args.pr_number !== undefined)) throw new Error("Run mode requires run_id and no pr_number");
        if (!ctx.model?.id) throw new Error("The writing model runtime ID is unavailable");
        const key = args.key ?? randomUUID();
        try {
          value = await remote(call, "start", { owner: args.owner, repo: args.repo,
            ...(mode === "pr" ? { pr_number: args.pr_number } : { run_id: args.run_id, ...(args.attempt === undefined ? {} : { attempt: args.attempt }) }),
            ...(args.max_wait_seconds === undefined ? {} : { max_wait_seconds: args.max_wait_seconds }),
            model: ctx.model.id, key }, signal ?? new AbortController().signal, mode);
        } catch (error) {
          throw new Error(`Watch start not confirmed. Do not blindly retry. After inspecting the failure, reconcile with action start, the same arguments, and key ${key}; status/attach require an Executor run ID. ${String(error)}`);
        }
      } else {
        if (!args.run) throw new Error(`${args.action} requires an Executor run ID`);
        if (args.action === "cancel" && !ctx.model?.id) throw new Error("The writing model runtime ID is unavailable");
        value = await remote(call, args.action === "cancel" ? "cancel" : "status",
          { run: args.run, ...(args.action === "cancel" ? { model: ctx.model!.id } : {}) }, signal ?? new AbortController().signal);
      }
      if (terminal(value)) {
        observers.get(value.id)?.abort();
        observers.delete(value.id);
        pending.delete(value.id);
        persist();
      } else if (args.action === "start" || args.action === "attach") {
        pending.add(value.id);
        persist();
        attach(value.id, ctx);
      }
      return { content: [{ type: "text", text: JSON.stringify(value) + (!terminal(value) && observers.has(value.id)
        ? "\nCompletion delivery is attached. Return control; no manual polling is needed." : "") }], details: value };
    },
  });
}
