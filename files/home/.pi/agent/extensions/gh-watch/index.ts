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
    description: "Watch a specific GitHub Actions run through gh-agent on server-1. start returns immediately and automatically delivers completion; return control instead of polling or waiting. status inspects; attach restores delivery for an existing Executor watch; cancel stops only the observer workflow, not GitHub CI. Uses the existing MCP gateway and selected gh-agent PAT. This observes one run, not every PR check. No GitHub writes or automatic rerun/merge.",
    parameters: Type.Object({
      action: Type.Union([Type.Literal("start"), Type.Literal("status"), Type.Literal("attach"), Type.Literal("cancel")]),
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
        if (!args.owner || !args.repo || !args.run_id) throw new Error("start requires owner, repo, and run_id");
        if (!ctx.model?.id) throw new Error("The writing model runtime ID is unavailable");
        const key = args.key ?? randomUUID();
        try {
          value = await remote(call, "start", { owner: args.owner, repo: args.repo, run_id: args.run_id,
            ...(args.attempt === undefined ? {} : { attempt: args.attempt }),
            ...(args.max_wait_seconds === undefined ? {} : { max_wait_seconds: args.max_wait_seconds }),
            model: ctx.model.id, key }, signal ?? new AbortController().signal);
        } catch (error) {
          throw new Error(`Watch start not confirmed. Do not blindly retry; reconcile using start key ${key}. ${String(error)}`);
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
