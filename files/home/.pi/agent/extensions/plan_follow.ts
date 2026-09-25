import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type Item = { text: string; status: "done" | "active" | "blocked" | "available" };
type Plan = { items: Item[]; error?: string };

const ACTIVE = /\s*<!-- active -->\s*$/;
const BLOCKED = /\s*<!-- blocked: (.+?) -->\s*$/;

export function parsePlan(markdown: string): Plan {
	const items: Item[] = [];
	for (const line of markdown.split(/\r?\n/)) {
		const match = /^- \[([ xX])\](?: (.*))?$/.exec(line);
		if (!match) continue;
		const [, checked, body = ""] = match;
		const active = body.includes("<!-- active -->");
		const blocked = body.includes("<!-- blocked:");
		if (active && blocked) return { items, error: "An item is both active and blocked" };
		if ((active && !ACTIVE.test(body)) || (blocked && !BLOCKED.test(body))) {
			return { items, error: "A status marker must be at the end of its item" };
		}
		if (checked !== " " && (active || blocked)) return { items, error: "A completed item has a status marker" };
		const text = body.replace(ACTIVE, "").replace(BLOCKED, "").trim();
		if (!text) return { items, error: "An item has no description" };
		items.push({ text, status: checked !== " " ? "done" : active ? "active" : blocked ? "blocked" : "available" });
	}
	if (items.length === 0) return { items, error: "No top-level Markdown checklist found" };
	if (items.filter((item) => item.status === "active").length > 1) return { items, error: "More than one active item" };
	return { items };
}

async function loadPlan(path: string): Promise<Plan> {
	try {
		return parsePlan(await readFile(path, "utf8"));
	} catch (error) {
		return { items: [], error: error instanceof Error ? error.message : String(error) };
	}
}

function snapshot(plan: Plan): string {
	return JSON.stringify(plan.items);
}

export default function planFollow(pi: ExtensionAPI) {
	let path: string | undefined;
	let paused = false;
	let previous = "";
	let noProgress = 0;
	let continuations = 0;
	let failed = false;

	async function restore(ctx: ExtensionContext) {
		path = undefined;
		paused = false;
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type !== "custom" || entry.customType !== "plan-follow") continue;
			const data = entry.data as { path?: string; paused?: boolean };
			path = data.path;
			paused = data.paused === true;
		}
		noProgress = 0;
		continuations = 0;
		await updateWidget(ctx);
	}

	async function updateWidget(ctx: ExtensionContext) {
		if (!ctx.hasUI) return;
		if (!path) {
			ctx.ui.setWidget("plan-follow", undefined);
			return;
		}
		const plan = await loadPlan(path);
		if (plan.error) {
			ctx.ui.setWidget("plan-follow", [`Plan: ${path} — ${plan.error}`]);
			return;
		}
		const active = plan.items.find((item) => item.status === "active");
		const available = plan.items.filter((item) => item.status === "available");
		const blocked = plan.items.filter((item) => item.status === "blocked").length;
		const done = plan.items.filter((item) => item.status === "done").length;
		ctx.ui.setWidget("plan-follow", [
			`Plan${paused ? " (paused)" : ""}: ${path}`,
			`Working on: ${active?.text ?? "—"} | Available: ${available.length} | Blocked: ${blocked} | Done: ${done}/${plan.items.length}`,
			...(available.length ? [`Available: ${available.slice(0, 3).map((item) => item.text).join(" · ")}`] : []),
		]);
	}

	pi.on("session_start", (_event, ctx) => restore(ctx));
	pi.on("session_tree", (_event, ctx) => restore(ctx));

	pi.on("input", async (event, ctx) => {
		if (event.source !== "interactive" && event.source !== "rpc") return;
		const match = /^\/plan-follow\s+(.+?)\s*$/.exec(event.text);
		if (match) {
			path = resolve(ctx.cwd, match[1].replace(/^(["'])(.*)\1$/, "$2"));
			paused = false;
			noProgress = 0;
			continuations = 0;
			pi.appendEntry("plan-follow", { path, paused });
			await updateWidget(ctx);
		} else if (path && !paused) {
			// A new human instruction takes precedence over unattended continuation.
			paused = true;
			pi.appendEntry("plan-follow", { path, paused });
			await updateWidget(ctx);
		}
	});

	pi.registerCommand("plan-pause", {
		description: "Pause automatic plan continuation (keep the progress widget)",
		handler: async (_args, ctx) => {
			if (!path) return;
			paused = true;
			pi.appendEntry("plan-follow", { path, paused });
			await updateWidget(ctx);
		},
	});

	pi.on("agent_start", async (_event, ctx) => {
		failed = false;
		previous = path ? snapshot(await loadPlan(path)) : "";
	});
	pi.on("agent_end", (event) => {
		const assistants = event.messages.filter((message) => message.role === "assistant");
		const last = assistants.at(-1);
		failed = !last || last.stopReason === "error" || last.stopReason === "aborted";
	});
	pi.on("tool_result", (_event, ctx) => { void updateWidget(ctx); });
	pi.on("agent_settled", async (_event, ctx) => {
		await updateWidget(ctx);
		if (!path || paused || failed || ctx.hasPendingMessages()) return;
		const plan = await loadPlan(path);
		if (plan.error || !plan.items.some((item) => item.status === "available" || item.status === "active")) return;
		noProgress = snapshot(plan) === previous ? noProgress + 1 : 0;
		if (noProgress >= 2 || continuations >= 20) {
			paused = true;
			pi.appendEntry("plan-follow", { path, paused });
			await updateWidget(ctx);
			ctx.ui.notify("Plan continuation paused; review the plan before resuming with /plan-follow", "warning");
			return;
		}
		continuations++;
		pi.sendUserMessage(`Continue following ${path}. Reread it; choose any useful, unblocked work that needs no human input. Update item statuses and verify completed work. If nothing useful remains, mark blockers explicitly and stop.`, { deliverAs: "followUp" });
	});
}

// Future ideas (not MVP): inject the current plan state before each model call if
// the prompt alone proves insufficient across long tool-heavy runs; preserve
// progress in a fresh-session handoff instead of relying on lossy compaction.
// Record completion order if a "just completed" widget row becomes useful;
// checklist order is not completion order. Add optional dependencies/acceptance
// criteria only if real plans need them. Consider richer blocked reasons (human
// decision vs external prerequisite), an expandable plan UI, configurable
// continuation limits, and an independent completion audit if experience shows
// the lightweight prompt-and-file approach needs those features.
