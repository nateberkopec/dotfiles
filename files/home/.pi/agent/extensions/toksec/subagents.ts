import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function record(value: unknown): Record<string, unknown> {
	return value !== null && typeof value === "object" ? value as Record<string, unknown> : {};
}

// Query the owning extension rather than inferring liveness from completion messages.
export async function subagentsRunning(pi: ExtensionAPI): Promise<boolean> {
	if (!pi.getAllTools().some((tool) => tool.name === "subagent")) return false;
	const requestId = crypto.randomUUID();
	return new Promise((resolve, reject) => {
		const timeout = setTimeout(() => {
			unsubscribe();
			reject(new Error("TBHT: pi-subagents status timed out"));
		}, 2000);
		const unsubscribe = pi.events.on(`subagents:rpc:v1:reply:${requestId}`, (raw) => {
			clearTimeout(timeout);
			unsubscribe();
			const reply = record(raw);
			const fleet = record(record(reply.data).fleet);
			if (reply.version !== 1 || reply.requestId !== requestId || reply.success !== true || fleet.version !== 1 ||
				typeof fleet.totalActive !== "number" || !Number.isSafeInteger(fleet.totalActive) || fleet.totalActive < 0) {
				reject(new Error("TBHT: pi-subagents returned no valid fleet status"));
				return;
			}
			resolve(fleet.totalActive > 0);
		});
		pi.events.emit("subagents:rpc:v1:request", {
			version: 1, requestId, method: "status", source: { extension: "toksec" },
		});
	});
}
