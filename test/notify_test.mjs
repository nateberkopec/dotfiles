import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { createRequire, registerHooks } from "node:module";
import { join } from "node:path";
import { test } from "node:test";
import { pathToFileURL } from "node:url";

// Pi supplies pi-tui at runtime; resolve that same dependency for standalone tests.
const globalRoot = execFileSync("npm", ["root", "-g"], { encoding: "utf8" }).trim();
let agentPath = join(globalRoot, "@earendil-works", "pi-coding-agent", "package.json");
if (!existsSync(agentPath)) {
	const install = execFileSync("mise", ["where", "npm:@earendil-works/pi-coding-agent"], { encoding: "utf8" }).trim();
	agentPath = join(install, "node_modules", "@earendil-works", "pi-coding-agent", "package.json");
}
const requireFromPi = createRequire(agentPath);
const tuiUrl = pathToFileURL(requireFromPi.resolve("@earendil-works/pi-tui")).href;
registerHooks({
	resolve(specifier, context, nextResolve) {
		if (specifier === "@earendil-works/pi-tui") return { url: tuiUrl, shortCircuit: true };
		return nextResolve(specifier, context);
	},
});
const { default: notify } = await import("../files/home/.pi/agent/extensions/notify.ts");

function harness() {
	const handlers = new Map();
	notify({ on(name, handler) { handlers.set(name, handler); } });
	assert.deepEqual([...handlers.keys()], ["agent_end"]);
	return (messages, mode = "tui") => handlers.get("agent_end")({ messages }, { mode });
}

function capture(fn) {
	const writes = [];
	const original = process.stdout.write;
	process.stdout.write = (chunk) => { writes.push(String(chunk)); return true; };
	try { fn(); } finally { process.stdout.write = original; }
	return writes;
}

test("notifies at agent_end with the last assistant response, not a tool response", () => {
	const end = harness();
	const writes = capture(() => end([
		{ role: "assistant", content: "Earlier" },
		{ role: "assistant", content: [{ type: "text", text: "**Done** with [link](https://example.com)" }] },
		{ role: "toolResult", content: "Ignored" },
	]));
	assert.equal(writes.length, 1);
	assert.match(writes[0], /^\x1b\]777;notify;π;Done with link\x07$/);
});

test("does not emit terminal escapes in noninteractive modes", () => {
	const end = harness();
	assert.deepEqual(capture(() => end([{ role: "assistant", content: "Done" }], "print")), []);
});

test("falls back for empty responses and sanitizes control characters", () => {
	const end = harness();
	assert.deepEqual(capture(() => end([])), ["\x1b]777;notify;Ready for input;\x07"]);
	const [notification] = capture(() => end([{ role: "assistant", content: "Hi\x1b]777;notify;bad\x07" }]));
	assert.equal(notification.match(/\x1b/g)?.length, 1);
	assert.equal(notification.match(/\x07/g)?.length, 1);
});
