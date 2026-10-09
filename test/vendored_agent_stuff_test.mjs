import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import "./support/pi_tui_loader.mjs";

const { default: goalExtension } = await import("../files/home/.pi/agent/extensions/goal.ts");

const { default: answerExtension } = await import("../files/home/.pi/agent/extensions/answer.ts");

function harness() {
	const commands = new Map();
	const tools = new Map();
	const shortcuts = new Map();
	const entries = [];

	return {
		commands, tools, shortcuts, entries,
		pi: {
			on() {},
			registerCommand(name, command) { commands.set(name, command); },
			registerTool(tool) { tools.set(tool.name, tool); },
			registerShortcut(key, shortcut) { shortcuts.set(key, shortcut); },
			appendEntry(type, data) { entries.push({ type, data }); },
		},
	};
}

test("goal registers locally and retains tool-backed state transitions", async () => {
	const h = harness();
	goalExtension(h.pi);
	assert.ok(h.commands.has("goal"));
	assert.deepEqual([...h.tools.keys()], ["get_goal", "create_goal", "update_goal"]);
	const ctx = { hasUI: false, sessionManager: { getSessionId: () => "fixture" } };
	const execute = (name, params) => h.tools.get(name).execute("fixture", params, undefined, undefined, ctx);
	await execute("create_goal", { objective: "Synthetic test objective", token_budget: 100 });
	assert.equal((await execute("get_goal", {})).details.goal.status, "active");
	assert.equal((await execute("get_goal", {})).details.remainingTokens, 100);
	await execute("update_goal", { status: "complete" });
	assert.equal((await execute("get_goal", {})).details.goal.status, "complete");
	assert.deepEqual(h.entries.map((entry) => entry.data.action), ["set", "status"]);
});

test("answer registers its command and shortcut without making model calls", async () => {
	const h = harness();
	answerExtension(h.pi);
	assert.ok(h.commands.has("answer"));
	assert.ok(h.shortcuts.has("ctrl+."));
	const notifications = [];
	await h.commands.get("answer").handler("", { hasUI: false, ui: { notify: (...args) => notifications.push(args) } });
	assert.deepEqual(notifications, [["answer requires interactive mode", "error"]]);
});

test("managed settings no longer install the agent-stuff repository", () => {
	const settings = JSON.parse(readFileSync(new URL("../files/home/.pi/agent/settings.json", import.meta.url)));
	assert.doesNotMatch(JSON.stringify(settings.packages), /agent-stuff/);
});
