import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { EventEmitter } from "node:events";
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
	const events = new EventEmitter();
	const state = { active: 0, idle: true, pending: false, mode: "tui", malformed: false, installed: true, beforeReply: () => {} };
	const ctx = {
		get mode() { return state.mode; },
		isIdle: () => state.idle,
		hasPendingMessages: () => state.pending,
	};
	events.on("subagents:rpc:v1:request", ({ requestId }) => {
		queueMicrotask(() => {
			state.beforeReply();
			events.emit(`subagents:rpc:v1:reply:${requestId}`, state.malformed ? {} : {
				version: 1, requestId, success: true, data: { fleet: { version: 1, totalActive: state.active } },
			});
		});
	});
	notify({
		on(name, handler) { handlers.set(name, handler); },
		getAllTools: () => state.installed ? [{ name: "subagent" }] : [],
		events: {
			on(name, handler) { events.on(name, handler); return () => events.off(name, handler); },
			emit: (name, data) => events.emit(name, data),
		},
	});
	const dispatch = async (name, payload = {}) => handlers.get(name)?.(payload, ctx);
	const end = async (messages, mode = "tui") => {
		state.mode = mode;
		await dispatch("agent_start");
		await dispatch("agent_end", { messages });
		await dispatch("agent_settled");
	};
	return Object.assign(end, { dispatch, state, events });
}

async function capture(fn) {
	const writes = [];
	const original = process.stdout.write;
	process.stdout.write = (chunk) => { writes.push(String(chunk)); return true; };
	try { await fn(); } finally { process.stdout.write = original; }
	return writes;
}

 testPLACEHOLDER
