import "./support/pi_tui_loader.mjs";
import assert from "node:assert/strict";
import { test } from "node:test";

const { visibleWidth } = await import("@earendil-works/pi-tui");

import { WarningInbox } from "../files/home/.pi/agent/extensions/you-should-know/inbox.ts";

const { preview, warningCard } = await import("../files/home/.pi/agent/extensions/you-should-know/card.ts");

const theme = { fg: (_color, text) => text, bold: (text) => text };

const warning = (id, note = id) => ({
	id,
	note,
	source: `Evidence for ${id}`,
	decision: { confidence: 0.99, category: "security" },
});

const custom = (type, data, id) => ({ type: "custom", customType: `you-should-know-${type}`, data, id });

const fill = () => {
	const inbox = new WarningInbox();
	["one", "two", "three"].forEach((id) => inbox.add(warning(id)));

	return inbox;
};

test("queue retains original evidence/metadata, selection survives arrivals, and ack only removes its target", () => {
	const inbox = fill();
	inbox.move(1);
	const selected = inbox.current;
	inbox.add(warning("four"));
	inbox.add(warning("two", "Duplicate"));
	assert.equal(inbox.current, selected);
	assert.equal(inbox.pending.length, 4);
	inbox.acknowledge("one");
	assert.equal(inbox.current, selected);
	inbox.acknowledge("two");
	assert.equal(inbox.current.id, "three");
	inbox.move(-1);
	assert.equal(inbox.current.id, "four");
	assert.deepEqual(inbox.current, warning("four"));
	inbox.acknowledge("missing");
	assert.equal(inbox.pending.length, 2);
});

test("resume restores additive notes and per-ID acknowledgments, never newer review metadata", () => {
	const rows = [
		custom("note", { ...warning("one"), queued: true }),
		custom("note", { ...warning("two"), queued: true }),
		custom("review", { confidence: 0.2, category: "none" }),
		custom("acknowledged", { id: "one" }),
		custom("state", { enabled: false }),
	];

	const inbox = WarningInbox.restore(rows);
	assert.deepEqual(inbox.pending, [warning("two")]);
	assert.deepEqual(
		WarningInbox.restore(rows.slice(0, 2)).pending,
		[warning("one"), warning("two")],
		"ancestor branch excludes later acknowledgments",
	);
});

test("legacy migration preserves only last visible snapshot and its paired score", () => {
	const score = { confidence: 0.98, category: "security" };

	const rows = [
		custom("review", score),
		custom("note", { note: "Legacy", source: "Snapshot" }, "old"),
		custom("review", { confidence: 0.3, category: "none" }),
	];

	assert.deepEqual(WarningInbox.restore(rows).current, {
		id: "legacy:old",
		note: "Legacy",
		source: "Snapshot",
		decision: score,
	});
	assert.equal(WarningInbox.restore([...rows, custom("note", { note: "" })]).pending.length, 0);
	assert.deepEqual(
		WarningInbox.restore([...rows, custom("note", { ...warning("new"), queued: true })]).pending.map((w) => w.id),
		["legacy:old", "new"],
	);
});

test("malformed notes are ignored and persisted text/source are bounded and sanitized", () => {
	const inbox = new WarningInbox();

	for (const data of [null, {}, { id: "", note: "x" }, { id: 4, note: "x" }, { id: "one", note: "\x1b" }])
		inbox.add(data);
	assert.equal(inbox.pending.length, 0);
	inbox.add({
		id: "safe",
		note: "\x1b" + "x".repeat(1000),
		source: "s".repeat(30000),
		decision: { confidence: 9, category: "security" },
	});
	assert.equal(inbox.current.note.length, 600);
	assert.equal(inbox.current.note.includes("\x1b"), false);
	assert.equal(inbox.current.source.length, 24000);
	assert.equal(inbox.current.decision, undefined);
});

test("preview is at most two body lines plus overflow, includes metadata, and has no shortcut eyebrow", () => {
	for (const width of [0, 1, 3, 12, 40, 80, 120]) {
		const lines = preview("日本語 🙂 café " + "Long warning. ".repeat(20), warning("x").decision, 4, theme, width);
		assert.ok(lines.length <= 3);
		lines.forEach((line) => assert.ok(visibleWidth(line) <= width));
	}

	const lines = preview("Warning", warning("x").decision, 4, theme, 120);
	assert.match(lines.join("\n"), /YSK \(99%\|SEC\):/);
	assert.match(lines.join("\n"), /3 more waiting/);
	assert.doesNotMatch(lines.join("\n"), /Ctrl|review/);
	assert.equal(preview("Warning", undefined, 1, theme, 120).length, 1);
});

test("arrows select actions, Tab browses warnings, letters act directly, and Details pins the selected issue", () => {
	const inbox = fill();

	const results = [],
		acknowledged = [];

	const card = warningCard(
		inbox,
		theme,
		() => {},
		(result) => results.push(result),
		(item) => {
			acknowledged.push(item.id);
			inbox.acknowledge(item.id);
		},
	);

	card.handleInput("\x1b[C");
	assert.match(card.render(100).join("\n"), /\[ \(D\)etails \]/);
	card.handleInput("\t");
	assert.equal(inbox.current.id, "two");
	card.handleInput("\r");
	assert.equal(results[0].details.id, "two");
	inbox.add(warning("four"));
	assert.equal(results[0].details.source, "Evidence for two");
	card.handleInput("\x1b[Z");
	assert.equal(inbox.current.id, "one");
	card.handleInput("\x1b[65;2u");
	assert.deepEqual(acknowledged, ["one"]);
	assert.equal(inbox.current.id, "two");
	card.handleInput("b");
	assert.equal(results.at(-1), undefined);
	assert.equal(inbox.pending.length, 3);
	card.handleInput("\x1b");
	assert.equal(inbox.pending.length, 3);
	card.handleInput("D");
	assert.equal(results.at(-1).details.id, "two");
});

test("card widths, Unicode, scrolling, empty queue, and final acknowledgement return", () => {
	const inbox = new WarningInbox();
	inbox.add(warning("long", "日本語 🙂 café " + "Long warning. ".repeat(80)));
	let closed = 0;

	const card = warningCard(
		inbox,
		theme,
		() => {},
		() => closed++,
		(item) => inbox.acknowledge(item.id),
		() => 22,
	);

	for (const width of [0, 1, 3, 12, 40, 80, 120])
		card.render(width).forEach((line) => assert.ok(visibleWidth(line) <= width));
	const before = card.render(40).join("\n");
	card.handleInput("\x1b[B");
	assert.notEqual(card.render(40).join("\n"), before);
	card.handleInput("a");
	assert.equal(closed, 1);
	assert.equal(inbox.pending.length, 0);
	card.handleInput("\t");
	card.handleInput("\r");
	assert.equal(closed, 2);
});
