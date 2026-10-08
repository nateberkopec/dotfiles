import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { executeDotf } from "./runner";

export default function dotfRunExtension(pi: ExtensionAPI) {
	pi.registerTool({
		name: "dotf_run",
		label: "Run dotf",
		description:
			"Run the fixed ~/.dotfiles/bin/dotf run workflow in Pi's real terminal. Interactive by default for sudo authentication; interactive=false sets NONINTERACTIVE=1 for user-level setup, deferring privileged work and migrations. No command, path, or arbitrary environment can be supplied.",
		promptSnippet: "Run dotfiles convergence, interactively by default or user-level setup with interactive=false",
		promptGuidelines: [
			"Use dotf_run only when the user has explicitly authorized converging their machine with the current dotfiles checkout.",
		],
		parameters: Type.Object({
			interactive: Type.Optional(Type.Boolean({ description: "Run interactively for sudo authentication (default: true). False applies user-level setup only." })),
		}),

		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const interactive = params.interactive ?? true;
			const result = await executeDotf(ctx, interactive);
			return {
				content: [{ type: "text", text: interactive ? "dotf run completed successfully" : "User-level setup completed; privileged work and migrations remain pending" }],
				details: result,
			};
		},
	});

	pi.registerCommand("dotf-run", {
		description: "Run dotf in the current terminal (optional: noninteractive)",
		handler: async (args, ctx) => {
			try {
				const option = args.trim();
				if (option && option !== "noninteractive") throw new Error("Usage: /dotf-run [noninteractive]");
				const interactive = option !== "noninteractive";
				await executeDotf(ctx, interactive);
				ctx.ui.notify(interactive ? "dotf run completed successfully" : "User-level setup completed; privileged work and migrations remain pending", "info");
			} catch (error) {
				ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
			}
		},
	});
}
