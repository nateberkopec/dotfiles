import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { test } from "node:test";
import notifyExtension from "../files/home/.pi/agent/extensions/notify.ts";

function harness() {
  const handlers = new Map();
  const events = new EventEmitter();
  const entries = [];
  let active = 0;
  let schedules = [];
  let idle = true;
  let pending = false;
  const ctx = {
    hasUI: true,
    mode: "tui",
    isIdle: () => idle,
    hasPendingMessages: () => pending,
    sessionManager: { getBranch: () => entries },
    ui: { notify: (message) => { throw new Error(message); } },
  };
  const pi = {
    on: (event, handler) => { (handlers.get(event) ?? handlers.set(event, []).get(event)).push(handler); },
    events: {
      on: (event, handler) => { events.on(event, handler); return () => events.off(event, handler); },
      emit: (event, data) => events.emit(event, data),
    },
    getAllTools: () => [{ name: "subagent" }],
    appendEntry: (customType, data) => entries.push({ type: "custom", customType, data }),
  };
  events.on("subagents:rpc:v1:request", ({ method, requestId }) => {
    const data = method === "status"
      ? { fleet: { version: 1, totalActive: active } }
      : { details: { schedules: { records: schedules } } };
    queueMicrotask(() => events.emit(`subagents:rpc:v1:reply:${requestId}`, { success: true, data }));
  });
  notifyExtension(pi);
  const dispatch = async (event, payload = {}, context = ctx) => {
    for (const handler of handlers.get(event) ?? []) await handler(payload, context);
  };
  return {
    dispatch, events, ctx, entries,
    set active(value) { active = value; },
    set idle(value) { idle = value; },
    set pending(value) { pending = value; },
    set schedules(value) { schedules = value; },
  };
}

async function withNotifications(fn) {
  const writes = [];
  const original = process.stdout.write;
  process.stdout.write = (chunk, ...args) => {
    if (String(chunk).startsWith("\x1b]777;notify;")) { writes.push(String(chunk)); return true; }
    return original.call(process.stdout, chunk, ...args);
  };
  try { await fn(writes); } finally { process.stdout.write = original; }
}

const response = { messages: [{ role: "assistant", content: [{ type: "text", text: "**All done**" }] }] };
const flush = () => new Promise((resolve) => setTimeout(resolve, 10));

test("notifies once after settling, not at agent_end, and not while children are running", async () => {
  await withNotifications(async (writes) => {
    const h = harness();
    await h.dispatch("session_start");
    await h.dispatch("agent_start");
    await h.dispatch("agent_end", response);
    assert.equal(writes.length, 0);
    h.active = 1;
    await h.dispatch("agent_settled");
    assert.equal(writes.length, 0);
    h.active = 0;
    h.events.emit("subagent:async-complete");
    await flush();
    assert.equal(writes.length, 1);
    assert.match(writes[0], /777;notify;π;All done/);
    await h.dispatch("agent_settled");
    assert.equal(writes.length, 1);
    await h.dispatch("session_shutdown");
  });
});

test("waits for the parent follow-up after a child and notifies again for new work", async () => {
  await withNotifications(async (writes) => {
    const h = harness();
    await h.dispatch("session_start");
    await h.dispatch("agent_start");
    await h.dispatch("agent_end", response);
    h.active = 1;
    await h.dispatch("agent_settled");
    h.active = 0;
    h.idle = false;
    h.events.emit("subagent:process-terminal");
    await flush();
    assert.equal(writes.length, 0);
    h.idle = true;
    h.pending = true;
    await h.dispatch("agent_settled");
    assert.equal(writes.length, 0);
    h.pending = false;
    await h.dispatch("agent_end", { messages: [{ role: "assistant", content: "Follow-up finished" }] });
    await h.dispatch("agent_settled");
    assert.equal(writes.length, 1);
    assert.match(writes[0], /Follow-up finished/);
    h.events.emit("subagent:async-started");
    h.events.emit("subagent:async-complete");
    await flush();
    assert.equal(writes.length, 2);
    await h.dispatch("session_shutdown");
  });
});

test("tracks only schedules created in this session, including across session start", async () => {
  await withNotifications(async (writes) => {
    const h = harness();
    await h.dispatch("session_start");
    await h.dispatch("agent_start");
    await h.dispatch("tool_call", { toolName: "subagent", toolCallId: "a", input: { action: "schedule.create" } });
    await h.dispatch("tool_result", { toolCallId: "a", details: { schedules: { records: [{ id: "ours" }] } } });
    const schedules = [
      { id: "other-window", trigger: { nextRunAt: "2030-01-01T00:00:00Z" } },
      { id: "ours", trigger: { nextRunAt: "2030-01-01T00:00:00Z" } },
    ];
    h.schedules = schedules;
    await h.dispatch("agent_settled");
    assert.equal(writes.length, 0);
    await h.dispatch("session_start");
    await h.dispatch("agent_start");
    schedules[1].paused = true;
    await h.dispatch("agent_settled");
    assert.equal(writes.length, 1);
    await h.dispatch("session_shutdown");
  });
});
