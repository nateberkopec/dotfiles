import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { registerHooks } from "node:module";
import net from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

registerHooks({ resolve(specifier, context, next) {
  if (specifier !== "typebox") return next(specifier, context);
  return { shortCircuit: true, url: `data:text/javascript,${encodeURIComponent("export const Type = new Proxy({}, { get: (_, type) => (...args) => ({type, args}) });")}` };
} });
const { default: extension } = await import("../files/home/.pi/agent/extensions/herdr-status/index.ts");

async function until(predicate) {
  const deadline = Date.now() + 2500;
  while (!predicate()) {
    if (Date.now() > deadline) assert.fail("Timed out waiting for Herdr report");
    await new Promise(resolve => setTimeout(resolve, 5));
  }
}

async function harness(t, entries = []) {
  const dir = await mkdtemp(join(tmpdir(), "herdr-test-"));
  const socketPath = join(dir, "api.sock");
  const reports = [];
  const sockets = new Set();
  const server = net.createServer(socket => {
    sockets.add(socket);
    socket.on("close", () => sockets.delete(socket));
    let buffer = "";
    socket.on("data", data => {
      buffer += data;
      if (!buffer.includes("\n")) return;
      const request = JSON.parse(buffer.split("\n")[0]);
      reports.push(request);
      socket.end(JSON.stringify({ id: request.id, result: {} }) + "\n");
    });
  });
  await new Promise(resolve => server.listen(socketPath, resolve));
  const saved = { ...process.env };
  Object.assign(process.env, { HERDR_ENV: "1", HERDR_PANE_ID: "w1:p1", HERDR_SOCKET_PATH: socketPath });
  delete process.env.PI_SUBAGENT_CHILD;
  const handlers = new Map();
  const tools = new Map();
  const commands = new Map();
  const bus = new EventEmitter();
  const state = { idle: true, children: 0, hasSubagents: true };
  const ctx = { mode: "tui", isIdle: () => state.idle,
    sessionManager: { getSessionFile: () => "/synthetic/session.jsonl", getSessionId: () => "synthetic-session", getBranch: () => entries },
    ui: { notify() {} } };
  const pi = {
    on: (name, handler) => handlers.set(name, handler),
    events: { on: (name, handler) => { bus.on(name, handler); return () => bus.off(name, handler); }, emit: (name, data) => bus.emit(name, data) },
    getAllTools: () => state.hasSubagents ? [{ name: "subagent" }] : [],
    registerTool: tool => tools.set(tool.name, tool),
    registerCommand: (name, command) => commands.set(name, command),
    appendEntry: (customType, data) => entries.push({ type: "custom", customType, data }),
  };
  bus.on("subagents:rpc:v1:request", request => bus.emit(`subagents:rpc:v1:reply:${request.requestId}`, {
    version: 1, requestId: request.requestId, success: true, data: { fleet: { version: 1, totalActive: state.children } },
  }));
  extension(pi);
  process.env = saved;
  const h = { handlers, tools, commands, bus, reports, state, ctx, entries, pi,
    current: () => reports.filter(r => r.method === "pane.report_agent").at(-1)?.params,
    async expect(value) { await until(() => this.current()?.state === value); },
    async start() { await handlers.get("session_start")({ reason: "startup" }, ctx); },
    async request(reason = "Choose the deployment window") { await tools.get("human_attention").execute("call", { reason }, undefined, undefined, ctx); },
  };
  t.after(async () => {
    handlers.get("session_shutdown")?.();
    for (const socket of sockets) socket.destroy();
    await new Promise(resolve => server.close(resolve));
    await rm(dir, { recursive: true, force: true });
  });
  return h;
}

test("parent lifecycle uses Herdr's authority and reports session identity", async t => {
  const h = await harness(t);
  await h.start();
  await h.expect("idle");
  assert.equal(h.reports[0].method, "pane.report_agent_session");
  assert.equal(h.reports[0].params.session_start_source, "startup");
  h.state.idle = false;
  h.handlers.get("agent_start")({}, h.ctx);
  await h.expect("working");
  h.state.idle = true;
  await h.handlers.get("agent_settled")({}, { ...h.ctx });
  await h.expect("idle");
  for (const report of h.reports) {
    assert.equal(report.params.source, "herdr:pi");
    assert.equal(report.params.agent_session_path, "/synthetic/session.jsonl");
  }
});

test("delegated work remains working after parent settles and clears on completion", async t => {
  const h = await harness(t);
  await h.start();
  h.state.children = 1;
  h.bus.emit("herdr:busy", { active: true, label: "child running" });
  await h.handlers.get("agent_settled")({}, h.ctx);
  await h.expect("working");
  h.state.children = 0;
  h.bus.emit("herdr:busy", { active: false });
  await h.expect("idle");
});

test("busy overlays are counted and retain parent activity after the last overlay clears", async t => {
  const h = await harness(t);
  await h.start();
  h.bus.emit("herdr:busy", { active: true });
  h.bus.emit("herdr:busy", { active: true });
  h.bus.emit("herdr:busy", { active: false });
  await h.expect("working");
  h.state.idle = false;
  h.handlers.get("agent_start")({}, h.ctx);
  h.bus.emit("herdr:busy", { active: false });
  assert.equal(h.current().state, "working");
  h.state.idle = true;
  await h.handlers.get("agent_settled")({}, h.ctx);
  await h.expect("idle");
});

test("busy label replacement never sends a false idle transition", async t => {
  const h = await harness(t);
  await h.start();
  h.bus.emit("herdr:busy", { active: true, label: "first task" });
  await h.expect("working");
  const before = h.reports.length;
  h.bus.emit("herdr:busy", { active: false });
  h.bus.emit("herdr:busy", { active: true, label: "next task" });
  await until(() => h.reports.length > before);
  assert.ok(h.reports.slice(before).every(report => report.params.state === "working"));
});

test("reload restores active delegated work from authoritative fleet status", async t => {
  const h = await harness(t);
  h.state.children = 2;
  await h.start();
  await h.expect("working");
  h.state.children = 0;
  h.bus.emit("herdr:busy", { active: false });
  await h.expect("idle");
});

test("invalid fleet status is not evidence of completed work", async t => {
  const h = await harness(t);
  h.state.children = -1;
  await h.start();
  await h.expect("working");
  h.state.children = 0;
  await h.handlers.get("agent_settled")({}, h.ctx);
  await h.expect("idle");
});

test("malformed overlays cannot clear active work", async t => {
  const h = await harness(t);
  await h.start();
  h.bus.emit("herdr:busy", { active: true });
  await h.expect("working");
  h.bus.emit("herdr:busy", {});
  h.bus.emit("herdr:busy", null);
  h.bus.emit("herdr:blocked", { active: "yes" });
  assert.equal(h.current().state, "working");
  h.bus.emit("herdr:busy", { active: false });
  await h.expect("idle");
});

test("human request overrides children and survives agent wakes and reload", async t => {
  const h = await harness(t);
  h.state.children = 1;
  await h.start();
  await h.request();
  await h.expect("blocked");
  assert.equal(h.current().message, "Choose the deployment window");
  h.state.idle = false;
  h.handlers.get("agent_start")({}, h.ctx);
  h.state.idle = true;
  await h.handlers.get("agent_settled")({}, h.ctx);
  await h.start();
  await h.expect("blocked");
  h.handlers.get("input")({ source: "extension" }, h.ctx);
  assert.equal(h.entries.at(-1).data.reason, "Choose the deployment window");
  h.handlers.get("input")({ source: "interactive" }, h.ctx);
  await h.expect("working");
  assert.equal(h.entries.at(-1).data.reason, null);
});

test("user dialogs override working and return to working without clearing a separate human request", async t => {
  const h = await harness(t);
  h.state.children = 1;
  await h.start();
  h.handlers.get("ui_prompt_start")({ kind: "confirm", title: "Allow deployment?" });
  await h.expect("blocked");
  await h.request("Need your approval");
  h.handlers.get("ui_prompt_end")({ kind: "confirm" });
  assert.equal(h.entries.at(-1).data.reason, "Need your approval");
  h.handlers.get("input")({ source: "interactive" }, h.ctx);
  await h.expect("working");
  h.handlers.get("ui_prompt_start")({ kind: "input", title: "Answer" });
  await h.expect("blocked");
  h.handlers.get("ui_prompt_end")({ kind: "input" });
  await h.expect("working");
});

test("existing blocked overlays remain supported until pi-subagents stops emitting them", async t => {
  const h = await harness(t);
  await h.start();
  h.bus.emit("herdr:busy", { active: true });
  h.bus.emit("herdr:blocked", { active: true, label: "Existing overlay" });
  await h.expect("blocked");
  h.bus.emit("herdr:blocked", { active: false });
  await h.expect("working");
});

test("attention is tool-only, without slash commands", async t => {
  const h = await harness(t);
  assert.equal(h.commands.size, 0);
  assert.ok(h.tools.has("human_attention"));
});

test("non-TUI sessions never publish or allow the attention tool", async t => {
  const h = await harness(t);
  h.ctx.mode = "rpc";
  await h.start();
  h.bus.emit("herdr:busy", { active: true });
  h.handlers.get("agent_start")({}, h.ctx);
  assert.equal(h.reports.length, 0);
  await assert.rejects(h.request(), /owning Herdr TUI/);
});

test("headless children and non-Herdr processes register nothing", () => {
  const saved = { ...process.env };
  const pi = new Proxy({}, { get() { throw new Error("Must not register child hooks"); } });
  try {
    Object.assign(process.env, { HERDR_ENV: "1", HERDR_PANE_ID: "w1:p1", HERDR_SOCKET_PATH: "/unused", PI_SUBAGENT_CHILD: "1" });
    extension(pi);
    delete process.env.PI_SUBAGENT_CHILD;
    process.env.HERDR_ENV = "0";
    extension(pi);
  } finally { process.env = saved; }
});

test("personal settings exclude only the managed status extension", async () => {
  const settings = JSON.parse(await readFile(new URL("../files/home/.pi/agent/settings.json", import.meta.url), "utf8"));
  assert.ok(settings.extensions.includes("-extensions/herdr-agent-state.ts"));
  assert.ok(!settings.extensions.includes("-extensions/herdr-status"));
  assert.ok(settings.packages.includes("npm:pi-subagents@0.75.0"));
});
