import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import { Value } from "typebox/value";
import { FleetStatusReply } from "../shared/subagent_status.ts";

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

			if (!Value.Check(FleetStatusReply, raw) || raw.requestId !== requestId) {
				reject(new Error("TBHT: pi-subagents returned no valid fleet status"));

				return;
			}

			resolve(raw.data.fleet.totalActive > 0);
		});

		pi.events.emit("subagents:rpc:v1:request", {
			version: 1,
			requestId,
			method: "status",
			source: { extension: "toksec" },
		});
	});
}
