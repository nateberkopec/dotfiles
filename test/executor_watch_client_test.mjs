import assert from "node:assert/strict";
import { test } from "node:test";
import { executorValue, observe, workflowGet } from "../files/home/.pi/agent/extensions/executor-watch/client.ts";

const watch = { app: "app_1", run: "wfr_1" };

const handle = (status, id = "wfr_1") => {
	const value = { id, app: "app_1", workflow: "any_workflow", status };

	if (status === "complete") value.output = { conclusion: "failure" };

	return value;
};

const envelope = (value) => ({ status: "completed", execution: { ok: true, value } });

const result = (value) => ({ content: [{ type: "text", text: JSON.stringify(envelope(value)) }] });

const emitter = (respond) => {
	const requests = [];

	return {
		requests,
		emit: (channel, request) => {
			requests.push({ channel, request });
			request.result = respond(request);
		},
	};
};

test("reads Executor results from gateway JSON text or raw MCP details", () => {
	assert.deepEqual(executorValue(result(handle("running"))), handle("running"));
	assert.deepEqual(
		executorValue({
			content: [
				{
					type: "text",
					text:
						JSON.stringify(envelope(handle("running"))) +
						"\nstructuredContent:\n" +
						JSON.stringify(envelope(handle("running"))),
				},
			],
		}),
		handle("running"),
	);
	assert.deepEqual(
		executorValue({ details: { mcpResult: { structuredContent: envelope(handle("complete")) } } }),
		handle("complete"),
	);
	assert.throws(
		() =>
			executorValue({
				content: [
					{ type: "text", text: JSON.stringify({ status: "completed", execution: { ok: false, error: "no" } }) },
				],
			}),
		/operation failed/,
	);
	assert.throws(
		() =>
			executorValue({ content: [{ type: "text", text: '{"status":"approval-required","requestId":"approval-1"}' }] }),
		/approval-1/,
	);
});

test("workflowGet pins server-1, discovers the Executor profile, and passes only serialized data", async () => {
	const run = 'wfr_";bad()';
	const e = emitter(async () => ({ ok: true, result: result(handle("running", run)) }));
	assert.deepEqual(await workflowGet(e.emit, { app: "app_1", run }), handle("running", run));
	const { channel, request } = e.requests[0];
	assert.equal(channel, "pi-mcp-adapter:runtime-tool-call:v1");
	assert.equal(request.server, "server-1");
	assert.equal(request.tool, "server-1_execute");
	assert.ok(request.args.code.includes("Object.keys(tools.executor.profiles)"));
	assert.ok(request.args.code.includes('workflows.get({"path":{"app":"app_1","run":"wfr_\\";bad()"}})'));
});

test("workflowGet surfaces adapter errors and rejects handles for other runs", async () => {
	await assert.rejects(
		workflowGet(() => {}, watch),
		/pi-mcp-adapter is not loaded/,
	);
	await assert.rejects(
		workflowGet(
			emitter(async () => ({ ok: false, error: new Error("MCP tool call failed: tool_not_found") })).emit,
			watch,
		),
		/tool_not_found/,
	);
	await assert.rejects(
		workflowGet(emitter(async () => ({ ok: true, result: result(handle("complete", "wfr_other")) })).emit, watch),
		/Invalid/,
	);
	await assert.rejects(
		workflowGet(
			emitter(async () => ({ ok: true, result: result({ ...handle("complete"), status: "bogus" }) })).emit,
			watch,
		),
		/Invalid/,
	);
});

test("observer polls and delivers only the terminal result, once", async () => {
	const statuses = ["queued", "running", "complete"];
	const deliveries = [];
	let sleeps = 0;
	await observe(
		watch,
		async () => handle(statuses.shift()),
		new AbortController().signal,
		(value) => deliveries.push(value),
		async () => {
			sleeps++;
		},
	);
	assert.equal(sleeps, 2);
	assert.deepEqual(deliveries, [handle("complete")]);
});

test("observer retries transient failure but surfaces sustained tracking failure", async () => {
	let count = 0;
	const delivered = [];
	await observe(
		watch,
		async () => {
			if (++count < 3) throw new Error("offline");

			return handle("terminated");
		},
		new AbortController().signal,
		(value) => delivered.push(value),
		async () => {},
	);
	assert.deepEqual(delivered, [handle("terminated")]);
	await observe(
		{ app: "app_1", run: "wfr_2" },
		async () => {
			throw new Error("offline");
		},
		new AbortController().signal,
		(value) => delivered.push(value),
		async () => {},
	);
	assert.deepEqual(delivered[1], { id: "wfr_2", status: "tracking_error", error: "Error: offline" });
});

test("abort suppresses stale completion", async () => {
	const controller = new AbortController();
	let delivered = false;
	await observe(
		watch,
		async () => {
			controller.abort();

			return handle("complete");
		},
		controller.signal,
		() => {
			delivered = true;
		},
		async () => {},
	);
	assert.equal(delivered, false);
});
