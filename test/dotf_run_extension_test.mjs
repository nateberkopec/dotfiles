import assert from "node:assert/strict";
import childProcess from "node:child_process";
import { EventEmitter } from "node:events";
import { registerHooks, syncBuiltinESMExports } from "node:module";
import { mock, test } from "node:test";

registerHooks({ resolve(specifier, context, next) {
  if (specifier === "typebox") return { shortCircuit: true, url: `data:text/javascript,${encodeURIComponent("export const Type = new Proxy({}, { get: (_, type) => (...args) => ({type, args}) });")}` };
  if (specifier === "./runner" && context.parentURL?.includes("/dotf_run/")) return { shortCircuit: true, url: new URL("./runner.ts", context.parentURL).href };
  return next(specifier, context);
} });
let calls = [];
let exitCode = 0;
mock.method(childProcess, "spawnSync", (executable, args) => {
  calls.push({ executable, args });
  return { status: 0 };
});
mock.method(childProcess, "spawn", (executable, args, options) => {
  calls.push({ executable, args, options });
  const child = new EventEmitter();
  child.kill = () => {};
  queueMicrotask(() => child.emit("exit", exitCode, null));
  return child;
});
syncBuiltinESMExports();
const { default: extension } = await import("../.pi/extensions/dotf_run/index.ts");
function harness() {
  calls = [];
  exitCode = 0;
  let tool, command;
  const terminal = [];
  const notifications = [];
  const ctx = { mode: "tui", ui: {
    custom: (factory) => new Promise((done) => factory({ stop: () => terminal.push("stop"), start: () => terminal.push("start"), requestRender: () => {} }, null, null, done)),
    notify: (...args) => notifications.push(args),
  } };
  extension({ registerTool: (value) => { tool = value; }, registerCommand: (_name, value) => { command = value; } });
  return { ctx, tool, command, terminal, notifications };
}

async function withInheritedMode(run) {
  const original = { NONINTERACTIVE: process.env.NONINTERACTIVE, DOTF_NO_SUDO: process.env.DOTF_NO_SUDO };
  process.env.NONINTERACTIVE = "1";
  process.env.DOTF_NO_SUDO = "1";
  try { await run(); }
  finally { for (const [key, value] of Object.entries(original)) { if (value === undefined) delete process.env[key]; else process.env[key] = value; } }
}
test("default run enables interactive sudo despite Pi's inherited environment", async () => {
  const h = harness();
  await withInheritedMode(async () => {
    await h.tool.execute("call", {}, undefined, undefined, h.ctx);
    const child = calls.find((call) => call.options);
    assert.deepEqual(child.args, ["run"]);
    assert.equal(child.options.env.NONINTERACTIVE, undefined);
    assert.equal(child.options.env.DOTF_NO_SUDO, undefined);
    assert.equal(child.options.stdio, "inherit");
    assert.equal(process.env.NONINTERACTIVE, "1");
    assert.deepEqual(calls.filter((call) => !call.options).map((call) => [call.executable, call.args]), [["/usr/bin/sudo", ["-k"]], ["/usr/bin/sudo", ["-k"]]]);
  });
  assert.deepEqual(h.terminal, ["stop", "start"]);
});
test("no-sudo run passes the CLI flag and never touches sudo credentials", async () => {
  const h = harness();
  const result = await h.tool.execute("call", { sudo: false }, undefined, undefined, h.ctx);
  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0].args, ["run", "--no-sudo"]);
  assert.equal(calls[0].options.env.NONINTERACTIVE, "1");
  assert.match(result.content[0].text, /remain pending/);
  assert.deepEqual(h.terminal, ["stop", "start"]);
});
test("no-sudo command validates arguments before starting", async () => {
  const h = harness();
  await h.command.handler("--bad", h.ctx);
  assert.equal(calls.length, 0);
  assert.match(h.notifications[0][0], /Usage/);
  await h.command.handler("--no-sudo", h.ctx);
  assert.deepEqual(calls[0].args, ["run", "--no-sudo"]);
});
test("failed no-sudo runs restore the terminal without invoking sudo", async () => {
  const h = harness();
  exitCode = 23;
  await assert.rejects(h.tool.execute("call", { sudo: false }, undefined, undefined, h.ctx), /code 23/);
  assert.equal(calls.length, 1);
  assert.deepEqual(h.terminal, ["stop", "start"]);
});
