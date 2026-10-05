import assert from "node:assert/strict";
import { test } from "node:test";
import { executorValue, observe, remote } from "../files/home/.pi/agent/extensions/gh-watch/client.ts";
const handle = (status) => ({ id: "watch-1", workflow: "watch_actions_run", status, ...status === "complete" ? { output: { conclusion: "failure" } } : {} });
const envelope = (value) => ({ status: "completed", execution: { ok: true, value } });
const result = (value) => ({ content: [{ type: "text", text: JSON.stringify(envelope(value)) }] });
test("reads Executor results from structured content or gateway JSON text", () => {
  assert.deepEqual(executorValue(result(handle("running"))), handle("running"));
  assert.deepEqual(executorValue({ structuredContent: envelope(handle("complete")) }), handle("complete"));
  assert.deepEqual(executorValue({ content: [{ type: "text", text: JSON.stringify(envelope(handle("running"))) + "\nstructuredContent:\n" + JSON.stringify(envelope(handle("running"))) }] }), handle("running"));
  assert.deepEqual(executorValue({ details: { mcpResult: { structuredContent: envelope(handle("complete")) } } }), handle("complete"));
  assert.throws(() => executorValue({ structuredContent: { status: "approval-required" } }), /No automatic retry/);
  assert.throws(() => executorValue({ isError: true }), /MCP call failed/);
  assert.throws(() => executorValue({ structuredContent: { status: "completed", execution: { ok: false, error: "no" } } }), /operation failed/);
});
test("preserves gateway errors and incomplete Executor responses", () => {
  const text = 'Tool "server-1_execute" not found on server "client-default"';
  for (const failure of [
    { isError: true, content: [{ type: "text", text }] },
    { content: [{ type: "text", text }], details: { error: "tool_not_found" } },
  ]) assert.throws(() => executorValue(failure), /server-1_execute.*client-default/);
  assert.throws(() => executorValue({ structuredContent: { status: "approval-required", requestId: "approval-1" } }), /approval-1/);
});
test("remote discovers exact profile and passes only serialized data", async () => {
  let code = "";
  const value = await remote(async (args) => {
    code = args.args.code;
    return result(handle("running"));
  }, "status", { run: 'x";bad()' }, new AbortController().signal);
  assert.equal(value.id, "watch-1");
  assert.ok(code.includes("tools.search"));
  assert.ok(code.includes('queries.watch_get({"run":"x\\";bad()"})'));
  await assert.rejects(remote(async () => result({ id: "other", workflow: "other", status: "complete" }), "status", {}, new AbortController().signal), /Invalid/);
});
test("observer polls without model turns and delivers terminal result exactly once", async () => {
  const statuses = ["waiting", "running", "complete"];
  const deliveries = [];
  let sleeps = 0;
  await observe(
    "watch-1",
    async () => result(handle(statuses.shift())),
    new AbortController().signal,
    (value) => deliveries.push(value),
    async () => {
      sleeps++;
    }
  );
  assert.equal(sleeps, 2);
  assert.deepEqual(deliveries, [handle("complete")]);
});
test("observer retries transient gateway failure but surfaces sustained tracking failure", async () => {
  let count = 0;
  const delivered = [];
  await observe(
    "watch-1",
    async () => {
      if (++count < 3) throw new Error("offline");
      return result(handle("terminated"));
    },
    new AbortController().signal,
    (value) => delivered.push(value),
    async () => {
    }
  );
  assert.deepEqual(delivered, [handle("terminated")]);
  await observe(
    "watch-2",
    async () => {
      throw new Error("offline");
    },
    new AbortController().signal,
    (value) => delivered.push(value),
    async () => {
    }
  );
  assert.deepEqual(delivered[1], { id: "watch-2", status: "tracking_error" });
});
test("shutdown abort suppresses stale completion", async () => {
  const controller = new AbortController();
  let delivered = false;
  await observe(
    "watch-1",
    async () => {
      controller.abort();
      return result(handle("complete"));
    },
    controller.signal,
    () => {
      delivered = true;
    },
    async () => {
    }
  );
  assert.equal(delivered, false);
});
