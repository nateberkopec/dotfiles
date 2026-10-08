import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { executeDotf } from "./runner";

export default function dotfRunExtension(pi: ExtensionAPI) {
	pi.registerTool({
		name: "dotf_run",
		label: "Run dotf",
		description:
			"Run the fixed ~/.dotfiles/bin/dotf run workflow in Pi's real terminal. Defaults to interactive sudo authentication; sudo=false applies user-level setup only and defers privileged work and migrations. No command, path, or arbitrary environment can be supplied.",
		promptSnippet: "Run dotfiles convergence, with sudo by default or user-level setup with sudo=false",
		promptGuidelines: [
			"Use dotf_run only when the user has explicitly authorized converging their machine with the current dotfiles checkout.",
		],
		parameters: Type.Object({
			sudo: Type.Optional(Type.Boolean({ description: "Allow interactive sudo authentication (default: true). False defers privileged work and migrations." })),
		}),

		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const sudo = params.sudo ?? true;
			const result = await executeDotf(ctx, sudo);
			return {
				content: [{ type: "text", text: sudo ? "dotf run completed successfully" : "User-level setup completed; privileged work and migrations remain pending" }],
				details: result,
			};
		},
	});

	pi.registerCommand("dotf-run", {
		description: "Run dotf in the current terminal (optional: --no-sudo)",
		handler: async (args, ctx) => {
			try {
				const option = args.trim();
				if (option && option !== "--no-sudo") throw new Error("Usage: /dotf-run [--no-sudo]");
				const sudo = option !== "--no-sudo";
				await executeDotf(ctx, sudo);
				ctx.ui.notify(sudo ? "dotf run completed successfully" : "User-level setup completed; privileged work and migrations remain pending", "info");
			} catch (error) {
				ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
			}
		},
	});
}
