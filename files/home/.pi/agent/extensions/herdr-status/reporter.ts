import net from "node:net";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

interface AgentReport {
	agent_session_path?: string;
	agent_session_id?: string;
	session_start_source?: string;
	state?: "working" | "blocked" | "idle";
	message?: string;
}

interface ReportRequest {
	id: string;
	method: string;
	params: AgentReport & { pane_id?: string; source: string; agent: "pi"; seq: number };
}

export function createReporter(env: NodeJS.ProcessEnv) {
	const endpoint = process.platform === "win32" ? `\\\\.\\pipe\\${env.HERDR_SOCKET_PATH}` : env.HERDR_SOCKET_PATH!;
	let seq = Date.now() * 1000;
	let pending: AgentReport | undefined;
	let draining: Promise<void> | undefined;

	function attempt(request: ReportRequest, timeoutMs: number): Promise<boolean> {
		return new Promise((resolve) => {
			let done = false;
			let buffer = "";
			const socket = net.createConnection(endpoint);
			const timer = setTimeout(() => finish(false), timeoutMs);
			timer.unref();

			function finish(ok: boolean) {
				if (done) return;
				done = true;
				clearTimeout(timer);
				socket.destroy();
				resolve(ok);
			}

			for (const event of ["error", "end"]) socket.on(event, () => finish(false));
			socket.on("connect", () => socket.write(JSON.stringify(request) + "\n"));
			socket.on("data", (data) => {
				buffer += data;

				if (!buffer.includes("\n")) return;

				try {
					finish(!JSON.parse(buffer.split("\n")[0]).error);
				} catch {
					finish(false);
				}
			});
		});
	}

	async function send(method: string, params: AgentReport) {
		const request: ReportRequest = {
			id: `herdr:pi:${++seq}`,
			method,
			params: { pane_id: env.HERDR_PANE_ID, source: "herdr:pi", agent: "pi", seq, ...params },
		};

		if (!(await attempt(request, 500))) await attempt(request, 1500);
	}

	function identity(ctx: ExtensionContext) {
		const file = ctx.sessionManager.getSessionFile();

		return file ? { agent_session_path: file } : { agent_session_id: ctx.sessionManager.getSessionId() };
	}

	return {
		session: (ctx: ExtensionContext, reason?: string) =>
			send("pane.report_agent_session", { ...identity(ctx), session_start_source: reason }),
		state(ctx: ExtensionContext, state: "working" | "blocked" | "idle", message?: string) {
			pending = { ...identity(ctx), state, message };

			if (draining) return;
			draining = Promise.resolve()
				.then(async () => {
					while (pending) {
						const next = pending;
						pending = undefined;
						await send("pane.report_agent", next);
					}
				})
				.finally(() => {
					draining = undefined;
				});
		},
		clear() {
			pending = undefined;
		},
	};
}
