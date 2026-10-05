import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { Message } from "@earendil-works/pi-ai/compat";
import { createBackend, textOf, type ChatSpec } from "./backend.ts";

type Turn = { id: string; messages: Message[] };
export class SideChat {
	private turns: Turn[] = [];
	private spec?: ChatSpec;
	private backend?: Awaited<ReturnType<typeof import("./backend.ts").createBackend>>;
	private overlay?: ReturnType<typeof import("./overlay.ts").openOverlay>;
	private busy = false;
	private version = 0;
	private partial = "";
	private question = "";
	private status = "Ready";
	private pi: ExtensionAPI;
	private key: string;
	private create: typeof createBackend;
	constructor(pi: ExtensionAPI, key: string, create = createBackend) { this.pi = pi; this.key = key; this.create = create; }
	private cancel() {
		this.version++; this.cancelWait?.(); this.cancelWait = undefined; this.backend?.close(); this.backend = undefined;
		this.busy = false; this.partial = ""; this.question = ""; this.status = "Ready";
	}
	close() {
		this.cancel(); const overlay = this.overlay; this.overlay = undefined; overlay?.close();
	}
	restore(ctx: ExtensionContext) {
		this.close(); this.spec = undefined; this.turns = [];
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type !== "custom") continue;
			if (entry.customType === `${this.key}-chat-reset`) this.turns = [];
			const data = entry.data as Turn;
			if (entry.customType === `${this.key}-chat-turn` && typeof data?.id === "string" && Array.isArray(data.messages)) this.turns.push(data);
		}
		this.turns = this.turns.slice(-8);
	}
	reset() { this.close(); this.turns = []; this.pi.appendEntry(`${this.key}-chat-reset`, {}); }
	inject(ctx: ExtensionContext) {
		if (this.busy || !this.spec || !this.turns.some((t) => t.id === this.spec?.id)) {
			ctx.ui.notify("No completed side conversation to hand off.", "warning"); return;
		}
		this.pi.sendUserMessage(`${this.spec.title} side conversation:\n\n${this.transcript()}`, ctx.isIdle() ? {} : { deliverAs: "followUp" });
	}
	async open(ctx: ExtensionContext, spec: ChatSpec, question: string) {
		if (this.spec?.id !== spec.id) this.close();
		if (!this.busy) this.spec = spec;
		const version = this.version;
		if (ctx.mode === "tui" && (!this.overlay || this.overlay.closed)) {
			const { openOverlay } = await import("./overlay.ts");
			if (version !== this.version) return;
			this.overlay = openOverlay(ctx, { title: this.spec!.title, text: () => this.transcript(), status: () => this.status,
				submit: (text) => { void this.ask(ctx, text); }, cancel: () => this.cancel() });
		}
		if (question.trim()) await this.ask(ctx, question.trim());
		else if (ctx.mode !== "tui") ctx.ui.notify(`Usage: /${this.key === "ysk" ? "ysk-chat" : "btw"} <question>`, "warning");
	}
	private transcript() {
		const messages = this.turns.filter((t) => t.id === this.spec?.id).flatMap((t) => t.messages);
		const history = messages.filter((m) => m.role === "user" || m.role === "assistant")
			.map((m) => `${m.role === "user" ? "**You:**" : "**Assistant:**"}\n${textOf(m)}`).join("\n\n");
		return [this.spec?.opening, history, this.question ? `**You:** ${textOf({ content: this.question })}\n\n${this.partial || "…"}` : ""].filter(Boolean).join("\n\n");
	}
	private async ask(ctx: ExtensionContext, question: string) {
		if (this.busy) { ctx.ui.notify("Side chat is still responding.", "warning"); return; }
		const version = this.version, spec = this.spec!;
		this.busy = true; this.question = question; this.partial = ""; this.status = "Responding…"; this.overlay?.refresh();
		let backend: typeof this.backend;
		const interrupted = new Promise<void>((resolve) => { this.cancelWait = resolve; });
		const timeout = setTimeout(() => {
			if (version === this.version) { this.cancel(); this.status = "Request timed out."; this.overlay?.refresh(); }
		}, 40_000);
		try {
			const history = this.turns.filter((t) => t.id === spec.id).flatMap((t) => t.messages);
			backend = await this.create(ctx, { ...spec, seed: [...spec.seed, ...history] }, (text) => {
				if (version === this.version) { this.partial = text; this.overlay?.refresh(); }
			});
			if (version !== this.version) return;
			this.backend = backend;
			const result = await Promise.race([backend.run(question), interrupted]);
			if (!result || version !== this.version) return;
			const turn = { id: spec.id, messages: result.messages };
			this.turns.push(turn); this.turns = this.turns.slice(-8); this.pi.appendEntry(`${this.key}-chat-turn`, turn);
			this.status = "Ready";
		} catch {
			if (version === this.version) { this.status = "Request failed. No fallback or retry."; ctx.ui.notify(this.status, "warning"); }
		} finally {
			clearTimeout(timeout); backend?.close();
			if (version === this.version) {
				this.busy = false; this.backend = undefined; this.partial = ""; this.question = ""; this.cancelWait = undefined; this.overlay?.refresh();
			}
		}
	}
	private cancelWait?: () => void;
}
