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
  const result = await h.tool.execute("call", { action: "start", owner: "example", repo: "repo", run_id: 42 }, void 0, void 0, h.ctx);
  assert.ok(result.content[0].text.includes("Return control"));
  assert.ok(h.calls[0].args.args.code.includes('"model":"gpt-6.1-sol"'));
  assert.equal(h.calls[0].name, "mcp");
  h.events.get("session_shutdown")();
  await tick();
  assert.equal(h.messages.length, 0);
  assert.ok(h.calls.some((call) => call.options.signal.aborted));
  assert.deepEqual(h.entries.at(-1).data.pending, ["watch-1"]);
  assert.ok(!h.calls.some((call) => call.args.args.code.includes("mutations.watch_cancel")));
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
test("cancel calls only watch_cancel with model, never GitHub cancel", async () => {
  const h = harness();
  h.setStatus("terminated");
  await h.tool.execute("call", { action: "cancel", run: "watch-1" }, void 0, void 0, h.ctx);
  assert.equal(h.calls.length, 1);
  assert.ok(h.calls[0].args.args.code.includes("mutations.watch_cancel"));
  assert.ok(h.calls[0].args.args.code.includes('"model":"gpt-6.1-sol"'));
  assert.equal(h.messages.length, 0);
});
