import { Type } from "typebox";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { subagentsRunning } from "../notify/readiness.ts";
import { createReporter } from "./reporter.ts";

const entryType = "herdr-human-attention";
const overlay = (value: unknown) => {
  if (!value || typeof value !== "object" || !("active" in value) || typeof value.active !== "boolean") return;
  return { active: value.active, label: "label" in value && typeof value.label === "string" ? value.label : undefined };
};

export default function (pi: ExtensionAPI) {
  const env = process.env;
  if (env.HERDR_ENV !== "1" || !env.HERDR_SOCKET_PATH || !env.HERDR_PANE_ID || env.PI_SUBAGENT_CHILD === "1") return;
  const reporter = createReporter(env);
  let session: ExtensionContext | undefined;
  let active = false;
  let busyCount = 0;
  let restoredBusy = false;
  let blockedCount = 0;
  let blockedLabel: string | undefined;
  let prompts: string[] = [];
  let human: string | undefined;
  let revision = 0;
  let last: string | undefined;

  function publish(force = false) {
    if (!session) return;
    const message = human ?? prompts.at(-1) ?? (blockedCount ? blockedLabel : undefined);
    const state = human || prompts.length || blockedCount ? "blocked" : active || busyCount || restoredBusy ? "working" : "idle";
    const key = JSON.stringify([state, message]);
    if (!force && key === last) return;
    last = key;
    reporter.state(session, state, message);
  }

  async function reconcile(ctx: ExtensionContext) {
    const current = ++revision;
    const busy = await subagentsRunning(pi);
    if (session !== ctx || current !== revision) return;
    restoredBusy = busy;
    publish();
  }

  function restoreHuman(ctx: ExtensionContext) {
    human = undefined;
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "custom" || entry.customType !== entryType) continue;
      const reason = (entry.data as { reason?: unknown } | undefined)?.reason;
      human = typeof reason === "string" && reason.length <= 200 ? reason : undefined;
    }
  }

  function clearHuman() {
    if (!human) return;
    human = undefined;
    pi.appendEntry(entryType, { reason: null });
    publish();
  }

  async function start(event: { reason?: string }, ctx: ExtensionContext) {
    revision++;
    reporter.clear();
    session = ctx.mode === "tui" ? ctx : undefined;
    active = !ctx.isIdle();
    busyCount = blockedCount = 0;
    restoredBusy = false;
    blockedLabel = last = undefined;
    prompts = [];
    restoreHuman(ctx);
    if (!session) return;
    await reporter.session(ctx, event.reason);
    if (session !== ctx) return;
    await reconcile(ctx);
    publish(true);
  }

  pi.on("session_start", start);
  pi.on("session_tree", (_event, ctx) => start({}, ctx));
  pi.on("agent_start", (_event, ctx) => {
    if (!session) return;
    session = ctx;
    active = true;
    void reporter.session(ctx);
    publish();
  });
  pi.on("agent_settled", async (_event, ctx) => {
    if (!session || !ctx.isIdle()) return;
    session = ctx;
    active = false;
    await reconcile(ctx);
    publish();
  });
  pi.on("ui_prompt_start", event => {
    if (!session) return;
    prompts.push(event.title || "User input required");
    publish();
  });
  pi.on("ui_prompt_end", () => {
    if (!session) return;
    prompts.pop();
    publish();
  });
  pi.on("input", event => {
    if (session && event.source !== "extension") clearHuman();
  });

  const subscriptions = [
    pi.events.on("herdr:busy", value => {
      const data = overlay(value);
      if (!session || !data) return;
      revision++;
      restoredBusy = false;
      busyCount = Math.max(0, busyCount + (data?.active ? 1 : -1));
      publish();
    }),
    pi.events.on("herdr:blocked", value => {
      const data = overlay(value);
      if (!session || !data) return;
      blockedCount = Math.max(0, blockedCount + (data?.active ? 1 : -1));
      if (data?.active) blockedLabel = data.label;
      else if (!blockedCount) blockedLabel = undefined;
      publish();
    }),
  ];
  pi.on("session_shutdown", () => {
    session = undefined;
    revision++;
    reporter.clear();
    for (const unsubscribe of subscriptions) unsubscribe();
  });

  pi.registerTool({
    name: "human_attention",
    label: "Request human attention",
    description: "Mark this Herdr workflow as needing the user's input, decision, permission, or help, even while subagents are active. Call before asking the user and returning control. Do not call for child-to-parent supervisor decisions, ordinary background waits, or problems you can resolve yourself. State a short, non-sensitive reason; then explain the question to the user in your reply. The marker survives background agent wake-ups and reloads; user input clears it.",
    parameters: Type.Object({ reason: Type.String({ minLength: 1, maxLength: 200 }) }),
    async execute(_id, { reason }, _signal, _update, ctx) {
      if (!session || ctx.mode !== "tui") throw new Error("Human attention requires the owning Herdr TUI session");
      human = reason.trim();
      if (!human) throw new Error("A reason is required");
      pi.appendEntry(entryType, { reason: human });
      publish();
      return { content: [{ type: "text", text: "Human attention marked. Ask the user your question and return control. Background work does not clear this request." }], details: { reason: human } };
    },
  });
  pi.registerCommand("human-attention", {
    description: "Show the human-attention request, or clear it with /human-attention clear",
    handler: async (args, ctx) => {
      if (args.trim() === "clear") clearHuman();
      ctx.ui.notify(human ? `Human attention: ${human}` : "No human-attention request.", "info");
    },
  });
}
