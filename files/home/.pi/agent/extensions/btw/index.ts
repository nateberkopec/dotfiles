// Side-chat design adapted from mitsuhiko/agent-stuff/extensions/btw.ts (Apache-2.0; see LICENSE).
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { SideChat } from "./thread.ts";

export default function btw(pi: ExtensionAPI) {
	const chat = new SideChat(pi, "btw");
	pi.registerCommand("btw", {
		description: "Open a separate side conversation, or ask /btw <question>. --new starts fresh.",
		handler: async (args, ctx) => {
			let question = args.trim();
			if (/^--new(?:\s|$)/.test(question)) { chat.reset(); question = question.replace(/^--new\s*/, ""); }
			if (!ctx.model) { ctx.ui.notify("No model selected for BTW.", "warning"); return; }
			const { buildSessionContext, convertToLlm } = await import("@earendil-works/pi-coding-agent");
			const seed = convertToLlm(buildSessionContext(ctx.sessionManager.getBranch(), ctx.sessionManager.getLeafId()).messages);
			await chat.open(ctx, {
				id: "btw", title: `BTW · ${ctx.model.provider}/${ctx.model.id}`, model: ctx.model, seed,
				tools: ["read", "bash", "edit", "write"], thinking: pi.getThinkingLevel(),
				systemPrompt: `${ctx.getSystemPrompt()}\n\nYou are a separate BTW side assistant. Answer focused questions directly. Your only tools are read, bash, edit and write.`,
			}, question);
		},
	});
	pi.registerCommand("btw-inject", { description: "Explicitly send the BTW conversation to the main agent.", handler: async (_args, ctx) => chat.inject(ctx) });
	pi.on("session_start", (_event, ctx) => chat.restore(ctx));
	pi.on("session_tree", (_event, ctx) => chat.restore(ctx));
	pi.on("session_shutdown", () => chat.close());
}
