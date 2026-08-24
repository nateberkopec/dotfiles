import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { executeDotf } from "./runner";

export default function dotfRunExtension(pi: ExtensionAPI) {
	pi.registerTool({
		name: "dotf_run",
		label: "Run dotf",
		description:
			"Run the fixed ~/.dotfiles/bin/dotf run workflow in Pi's real terminal so the user can complete sudo authentication. No command, path, flags, or environment can be supplied.",
		promptSnippet: "Run the canonical dotfiles convergence workflow with interactive sudo authentication",
		promptGuidelines: [
			"Use dotf_run only when the user has explicitly authorized converging their machine with the current dotfiles checkout.",
		],
		parameters: Type.Object({}),

		async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
			const result = await executeDotf(ctx);
			return {
				content: [{ type: "text", text: "dotf run completed successfully" }],
				details: result,
			};
		},
	});

	pi.registerCommand("dotf-run", {
		description: "Run dotf interactively in the current terminal",
		handler: async (_args, ctx) => {
			try {
				await executeDotf(ctx);
				ctx.ui.notify("dotf run completed successfully", "info");
			} catch (error) {
				ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
			}
		},
	});
}
