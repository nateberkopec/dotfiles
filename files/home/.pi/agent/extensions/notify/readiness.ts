import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const record = (value: unknown): Record<string, unknown> =>
	value !== null && typeof value === "object" ? value as Record<string, unknown> : {};

/** Query the owning extension, including descendants, rather than guessing from prose. */
export async function subagentsRunning(pi: ExtensionAPI): Promise<boolean> {
	if (!pi.getAllTools().some((tool) => tool.name === "subagent")) return false;
	const requestId = crypto.randomUUID();
	return new Promise((resolve) => {
		// Fail closed: an unavailable or invalid status is not evidence of readiness.
		const timeout = setTimeout(() => {
			unsubscribe();
			resolve(true);
		}, 2000);
		const unsubscribe = pi.events.on(`subagents:rpc:v1:reply:${requestId}`, (raw) => {
			clearTimeout(timeout);
			unsubscribe();
			const reply = record(raw);
			const fleet = record(record(reply.data).fleet);
			const valid = reply.version === 1 && reply.requestId === requestId && reply.success === true &&
				fleet.version === 1 && typeof fleet.totalActive === "number" &&
				Number.isSafeInteger(fleet.totalActive) && fleet.totalActive >= 0;
			resolve(!valid || (fleet.totalActive as number) > 0);
		});
		pi.events.emit("subagents:rpc:v1:request", {
			version: 1, requestId, method: "status", source: { extension: "notify" },
		});
	});
}
