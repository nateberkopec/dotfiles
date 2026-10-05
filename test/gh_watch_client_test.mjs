import assert from "node:assert/strict";
import { test } from "node:test";
import { executorValue, observe, watchGet } from "../files/home/.pi/agent/extensions/gh-watch/client.ts";
const handle = (status) => ({ id: "wfr_1", workflow: "watch_pr_checks", status, ...status === "complete" ? { output: { conclusion: "failure" } } : {} });
const envelope = (value) => ({ status: "completed", execution: { ok: true, value } });
const result = (value) => ({ content: [{ type: "text", text: JSON.stringify(envelope(value)) }] });
const emitter = (respond) => {
  const requests = [];
  return { requests, emit: (channel, request) => { requests.push({ channel, request }); request.result = respond(request); } };
};
test("reads Executor results from gateway JSON text or raw MCP details", () => {
  assert.deepEqual(executorValue(result(handle("running"))), handle("running"));
  assert.deepEqual(executorValue({ content: [{ type: "text", text: JSON.stringify(envelope(handle("running"))) + "\nstructuredContent:\n" + JSON.stringify(envelope(handle("running"))) }] }), handle("running"));
  assert.deepEqual(executorValue({ details: { mcpResult: { structuredContent: envelope(handle("complete")) } } }), handle("complete"));
  assert.throws(() => executorValue({ content: [{ type: "text", text: JSON.stringify({ status: "completed", execution: { ok: false, error: "no" } }) }] }), /operation failed/);
  assert.throws(() => executorValue({ content: [{ type: "text", text: '{"status":"approval-required","requestId":"approval-1"}' }] }), /approval-1/);
});
test("watchGet pins server-1 and passes only serialized data", async () => {
  const e = emitter(async () => ({ ok: true, result: result(handle("running")) }));
  assert.deepEqual(await watchGet(e.emit, 'x";bad()'), handle("running"));
  const { channel, request } = e.requests[0];
  assert.equal(channel, "pi-mcp-adapter:runtime-tool-call:v1");
  assert.equal(request.server, "server-1");
  assert.equal(request.tool, "server-1_execute");
  assert.ok(request.args.code.includes('queries.watch_get({"run":"x\\";bad()"})'));
});
test("watchGet surfaces adapter errors and invalid handles", async () => {
  await assert.rejects(watchGet(() => {}, "wfr_1"), /pi-mcp-adapter is not loaded/);
  await assert.rejects(watchGet(emitter(async () => ({ ok: false, error: new Error("MCP tool call failed: tool_not_found") })).emit, "wfr_1"), /tool_not_found/);
  await assert.rejects(watchGet(emitter(async () => ({ ok: true, result: result({ id: "x", workflow: "other", status: "complete" }) })).emit, "wfr_1"), /Invalid/);
});
test("observer polls and delivers only the terminal result, once", async () => {
  const statuses = ["queued", "running", "complete"];
  const deliveries = [];
  let sleeps = 0;
  await observe("wfr_1", async () => handle(statuses.shift()), new AbortController().signal,
    (value) => deliveries.push(value), async () => { sleeps++; });
  assert.equal(sleeps, 2);
  assert.deepEqual(deliveries, [handle("complete")]);
});
test("observer retries transient failure but surfaces sustained tracking failure", async () => {
  let count = 0;
  const delivered = [];
  await observe("wfr_1", async () => {
    if (++count < 3) throw new Error("offline");
    return handle("terminated");
  }, new AbortController().signal, (value) => delivered.push(value), async () => {});
  assert.deepEqual(delivered, [handle("terminated")]);
  await observe("wfr_2", async () => { throw new Error("offline"); }, new AbortController().signal, (value) => delivered.push(value), async () => {});
  assert.deepEqual(delivered[1], { id: "wfr_2", status: "tracking_error", error: "Error: offline" });
});
test("abort suppresses stale completion", async () => {
  const controller = new AbortController();
  let delivered = false;
  await observe("wfr_1", async () => {
    controller.abort();
    return handle("complete");
  }, controller.signal, () => { delivered = true; }, async () => {});
  assert.equal(delivered, false);
});
