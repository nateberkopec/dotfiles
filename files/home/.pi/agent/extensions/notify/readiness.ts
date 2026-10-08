import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import { Value } from "typebox/value";
import { FleetStatusReply } from "../shared/subagent_status.ts";

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
			resolve(!Value.Check(FleetStatusReply, raw) || raw.requestId !== requestId || raw.data.fleet.totalActive > 0);
		});

		pi.events.emit("subagents:rpc:v1:request", {
			version: 1,
			requestId,
			method: "status",
			source: { extension: "notify" },
		});
	});
}
