import { writeFileSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function cardFixture(pi: ExtensionAPI) {
	pi.on("session_start", () => {
		for (const id of ["one", "two", "three"]) pi.appendEntry("you-should-know-note", {
			id, note: `Fixture ${id}: verify the backup before deleting data.`, source: `Original evidence for ${id}.`,
			decision: { confidence: 0.99, category: "security" }, queued: true,
		});
	});
	pi.registerCommand("ysk-card-proof", { description: "Capture the UI fixture's session entries", handler: async (_args, ctx) => {
		if (process.env.YSK_CARD_TRACE) writeFileSync(process.env.YSK_CARD_TRACE, JSON.stringify(ctx.sessionManager.getEntries()));
		ctx.ui.notify("Card proof captured", "info");
	} });
}
