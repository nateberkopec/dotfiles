import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const ROUTER_POLICY = `
IMPORTANT: Prefer implicit delegation through the subagent tool when appropriate.

If the subagent tool is available, follow this policy:
- Delegate by default for non-trivial tasks.
- Keep work in the main agent only when all are true:
  1) likely <10 minutes, 2) <=2 concrete steps, 3) little/no recon needed, 4) no specialist persona/tools needed.
- Before delegating, discover available agents/chains with: { "action": "list" }.
- Reuse existing agents first; if none fits, create a narrow temporary project agent via { "action": "create", "config": ... }.
- Use modes intentionally:
  - single: { agent, task }
  - chain: { chain:[...] }
  - parallel: { tasks:[...] }
- Prefer clarify:false for implicit flow unless user asks for interactive clarification.
- Clean up temporary agents with { "action": "delete", ... } unless user asks to keep them.
- Never perform destructive actions without explicit user confirmation.

When reporting back after delegated runs, include:
1) what was delegated and why,
2) key findings,
3) temp agents created/deleted,
4) recommended next step.
`;

export default function defaultSubagentRouter(pi: ExtensionAPI) {
	let routerEnabled = true;

	pi.registerCommand("router", {
		description: "Toggle implicit subagent routing policy",
		handler: async (_args, ctx) => {
			routerEnabled = !routerEnabled;
			ctx.ui.notify(
				routerEnabled ? "Implicit subagent routing enabled" : "Implicit subagent routing disabled",
				"info",
			);
		},
	});

	pi.on("before_agent_start", async (event) => {
		if (!routerEnabled) return undefined;

		return {
			systemPrompt: `${event.systemPrompt}\n\n${ROUTER_POLICY}`,
		};
	});
}
