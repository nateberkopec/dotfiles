import assert from "node:assert/strict";
import { registerHooks } from "node:module";
import { test } from "node:test";
registerHooks({ resolve(specifier, context, next) {
  if (specifier !== "typebox") return next(specifier, context);
  return { shortCircuit: true, url: `data:text/javascript,${encodeURIComponent("export const Type = new Proxy({}, { get: (_, type) => (...args) => ({type, args}) });")}` };
} });
const { default: extension } = await import("../files/home/.pi/agent/extensions/gh-watch/index.ts");
const handle = (status) => ({ id: "watch-1", workflow: "watch_actions_run", status });
const outcome = (status) => ({ result: { structuredContent: { status: "completed", execution: { ok: true, value: handle(status) } } }, isError: false });
const tick = () => new Promise((resolve) => setImmediate(resolve));
function harness() {
  const events = /* @__PURE__ */ new Map();
  const entries = [];
  const messages = [];
  const calls = [];
  let tool;
  let status = "running";
  const ctx = {
    model: { id: "gpt-6.1-sol" },
    sessionManager: { getBranch: () => entries },
    executeTool: async (name, args, options) => {
      calls.push({ name, args, options });
      return outcome(status);
    }
  };
  extension({
    on: (event, handler) => events.set(event, handler),
    registerTool: (value) => {
      tool = value;
    },
    appendEntry: (customType, data) => entries.push({ type: "custom", customType, data }),
    sendMessage: (message, options) => messages.push({ message, options })
  });
  return { events, entries, messages, calls, ctx, get tool() {
    return tool;
  }, setStatus: (value) => {
    status = value;
  } };
}
test("attach delivers completion through followUp and persists removal", async () => {
  const h = harness();
  h.setStatus("complete");
  let first = true;
  const base = h.ctx.executeTool;
  h.ctx.executeTool = async (...args) => first ? (first = false, outcome("running")) : base(...args);
  await h.tool.execute("call", { action: "attach", run: "watch-1" }, void 0, void 0, h.ctx);
  await tick();
  assert.equal(h.messages.length, 1);
  assert.equal(h.messages[0].message.customType, "gh-watch-complete");
  assert.deepEqual(h.messages[0].options, { triggerTurn: true, deliverAs: "followUp" });
  assert.deepEqual(h.entries.at(-1).data.pending, []);
});
test("start uses current model and returns without waiting; shutdown aborts observation only", async () => {
  const h = harness();
  const result = await h.tool.execute("call", { action: "start", mode: "run", owner: "example", repo: "repo", run_id: 42 }, void 0, void 0, h.ctx);
  assert.ok(result.content[0].text.includes("Return control"));
  assert.ok(h.calls[0].args.args.code.includes('"model":"gpt-6.1-sol"'));
  assert.equal(h.calls[0].name, "mcp");
  assert.ok(h.calls[0].args.args.code.includes("mutations.watch_actions_run"));
  h.events.get("session_shutdown")();
  await tick();
  assert.equal(h.messages.length, 0);
  assert.ok(h.calls.some((call) => call.options.signal.aborted));
  assert.deepEqual(h.entries.at(-1).data.pending, ["watch-1"]);
  assert.ok(!h.calls.some((call) => call.args.args.code.includes("mutations.watch_cancel")));
});
test("default start watches all PR checks, not an individual Actions run", async () => {
  const h = harness();
  const base = h.ctx.executeTool;
  h.ctx.executeTool = async (...args) => {
    const result = await base(...args);
    result.result.structuredContent.execution.value.workflow = "watch_pr_checks";
    return result;
  };
  await h.tool.execute("call", { action: "start", owner: "example", repo: "repo", pr_number: 850 }, undefined, undefined, h.ctx);
  assert.ok(h.calls[0].args.args.code.includes("mutations.watch_pr_checks"));
  assert.ok(h.calls[0].args.args.code.includes('"pr_number":850'));
  assert.ok(!h.calls[0].args.args.code.includes('"run_id"'));
  h.events.get("session_shutdown")();
});
test("rejects ambiguous or missing watch targets before remote calls", async () => {
  const h = harness();
  for (const args of [
    { run_id: 42 }, { pr_number: 850, run_id: 42 }, { pr_number: 850, attempt: 1 },
    { mode: "run", pr_number: 850 }, { mode: "run" },
  ]) await assert.rejects(h.tool.execute("call", { action: "start", owner: "example", repo: "repo", ...args }, undefined, undefined, h.ctx));
  assert.equal(h.calls.length, 0);
});
test("reload restores exact handles and requests attach, never starts replacement", async () => {
  const h = harness();
  h.entries.push({ type: "custom", customType: "gh-watch-state", data: { pending: ["watch-old"] } });
  h.events.get("session_start")({}, h.ctx);
  const reminder = h.events.get("before_agent_start")();
  assert.ok(reminder.message.content.includes("watch-old"));
  assert.equal(h.calls.length, 0);
});
test("switching sessions suppresses late completion from previous owner", async () => {
  const h = harness();
  let resolve;
  let count = 0;
  h.ctx.executeTool = async () => ++count === 1 ? outcome("running") : await new Promise((r) => {
    resolve = r;
  });
  await h.tool.execute("call", { action: "attach", run: "watch-1" }, void 0, void 0, h.ctx);
  await tick();
  h.events.get("session_shutdown")({ reason: "resume" });
  h.events.get("session_start")({ reason: "resume" }, h.ctx);
  resolve(outcome("complete"));
  await tick();
  assert.equal(h.messages.length, 0);
});
test("watch calls stay on server-1 when the gateway defaults to a selected client", async () => {
  const h = harness();
  const base = h.ctx.executeTool;
  h.ctx.executeTool = async (name, args, options) => {
    // The client-picker tool_call hook supplies its selection when server is omitted.
    const routed = { ...args, server: args.server ?? "client-default" };
    if (routed.server !== "server-1") return { isError: false, result: {
      content: [{ type: "text", text: `Tool "${args.tool}" not found on server "${routed.server}"` }],
      details: { error: "tool_not_found" },
    } };
    return base(name, routed, options);
  };
  try {
    await h.tool.execute("start", { action: "start", mode: "run", owner: "example", repo: "repo", run_id: 42 }, undefined, undefined, h.ctx);
    await tick();
    for (const action of ["status", "attach", "cancel"]) {
      if (action === "cancel") h.setStatus("terminated");
      await h.tool.execute(action, { action, run: "watch-1" }, undefined, undefined, h.ctx);
    }
    assert.ok(h.calls.length >= 5, "includes background completion observation");
    assert.ok(h.calls.every(call => call.args.server === "server-1"));
  } finally {
    h.events.get("session_shutdown")();
  }
});
test("failed starts explain how to reconcile with their stable key", async () => {
  const h = harness();
  h.ctx.executeTool = async () => { throw new Error("gateway unavailable"); };
  await assert.rejects(h.tool.execute("start", { action: "start", mode: "run", owner: "example", repo: "repo", run_id: 42, key: "start-key" }, undefined, undefined, h.ctx), /action start.*same arguments.*start-key.*status\/attach require an Executor run ID/);
});
test("cancel calls only watch_cancel with model, never GitHub cancel", async () => {
  const h = harness();
  h.setStatus("terminated");
  await h.tool.execute("call", { action: "cancel", run: "watch-1" }, void 0, void 0, h.ctx);
  assert.equal(h.calls.length, 1);
  assert.ok(h.calls[0].args.args.code.includes("mutations.watch_cancel"));
  assert.ok(h.calls[0].args.args.code.includes('"model":"gpt-6.1-sol"'));
  assert.equal(h.messages.length, 0);
});
