import { textOf } from "../../files/home/.pi/agent/extensions/you-should-know/transcript.ts";

export function parseSession(text) {
	const rows = text.split("\n").flatMap((line, index) => {
		if (!line.trim()) return [];
		try { return [JSON.parse(line)]; } catch { throw Error(`Invalid JSON on line ${index + 1}.`); }
	});
	if (rows[0]?.type !== "session") throw Error("Expected a Pi session JSONL header.");
	const entries = rows.slice(1), ids = new Set();
	let previous = null;
	for (const [index, entry] of entries.entries()) {
		if (!entry || typeof entry !== "object") throw Error(`Invalid session entry ${index + 1}.`);
		if ((rows[0].version ?? 1) === 1) { entry.id ??= `legacy-${index}`; entry.parentId = previous; }
		if (typeof entry.id !== "string" || ids.has(entry.id)) throw Error(`Missing or duplicate entry ID at entry ${index + 1}.`);
		if (entry.parentId != null && !ids.has(entry.parentId)) throw Error(`Missing or forward parent for entry ${entry.id}.`);
		ids.add(entry.id); previous = entry.id;
	}
	return { header: rows[0], entries };
}

export function branchOf(session, leaf = session.entries.at(-1)?.id) {
	const byId = new Map(session.entries.map((entry) => [entry.id, entry])), branch = [];
	if (leaf && !byId.has(leaf)) throw Error(`Unknown leaf: ${leaf}`);
	while (leaf) { const entry = byId.get(leaf); branch.push(entry); leaf = entry.parentId; }
	return branch.reverse();
}

export function snapshot(entries) {
	return entries.flatMap((entry) => {
		const message = entry.type === "message" && entry.message;
		return message && ["user", "assistant", "toolResult"].includes(message.role) && textOf(message)
			? [`${message.role}: ${textOf(message)}`] : [];
	}).join("\n\n").trim().slice(-24_000);
}

export function checkpoints(session, leaf) {
	const branch = branchOf(session, leaf), points = [];
	let lastStarted = -Infinity, lastSource = "";
	for (const [index, entry] of branch.entries()) {
		if (entry.type !== "message" || entry.message?.role !== "assistant") continue;
		const now = Date.parse(entry.timestamp), final = !["toolUse", "error", "aborted"].includes(entry.message.stopReason);
		if (!final && Number.isFinite(now) && now - lastStarted < 30_000) continue;
		const source = snapshot(branch.slice(0, index + 1));
		if (!source || source === lastSource) continue;
		points.push({ id: entry.id, timestamp: entry.timestamp, source });
		lastSource = source; lastStarted = Number.isFinite(now) ? now : lastStarted;
	}
	return points;
}

export function recordedWarnings(session, leaf) {
	const branch = branchOf(session, leaf), warnings = [];
	let review;
	for (const [index, entry] of branch.entries()) {
		if (entry.customType === "you-should-know-review") review = entry.data;
		if (entry.customType !== "you-should-know-note" || !entry.data?.note) continue;
		const issue = entry.data, prior = warnings.at(-1);
		if ((issue.id && prior?.issueId === issue.id) || prior?.note === issue.note) continue;
		warnings.push({ id: entry.id, issueId: issue.id, timestamp: entry.timestamp, note: issue.note,
			decision: { ...review, ...issue.decision }, source: issue.source || snapshot(branch.slice(0, index)),
			exactSnapshot: Boolean(issue.source) });
	}
	return warnings;
}
