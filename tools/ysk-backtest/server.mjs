import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { randomBytes } from "node:crypto";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { execFile } from "node:child_process";
import { parseSession, checkpoints, recordedWarnings, branchOf } from "./session.mjs";
import { replay } from "./replay.mjs";
import { observerContext } from "./runtime.mjs";

const MAX_BYTES = 64 * 1024 * 1024;

async function bodyOf(request) {
	let size = 0;
	const chunks = [];

	for await (const chunk of request) {
		size += chunk.length;

		if (size > MAX_BYTES) throw Error("Session exceeds the 64 MiB limit.");
		chunks.push(chunk);
	}

	return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

export async function startServer({ text, name, port = 0, leaf, context = observerContext, evaluate } = {}) {
	let session = parseSession(text),
		points = checkpoints(session, leaf),
		controller,
		task;

	const token = randomBytes(24).toString("hex");

	let state = { status: "ready", completed: 0, warnings: [], error: "" },
		mode = "recorded";

	const summary = () => ({
		name,
		cwd: session.header.cwd,
		sessionId: session.header.id,
		leaf: leaf || session.entries.at(-1)?.id,
		entries: branchOf(session, leaf).length,
		checkpoints: points.length,
	});

	const server = createServer(async (request, response) => {
		const address = server.address(),
			host = `127.0.0.1:${address.port}`,
			origin = `http://${host}`;

		response.setHeader("Cache-Control", "no-store");
		response.setHeader("X-Content-Type-Options", "nosniff");
		response.setHeader("Referrer-Policy", "no-referrer");
		response.setHeader(
			"Content-Security-Policy",
			"default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
		);

		const send = (status, data) => {
			response.writeHead(status, { "Content-Type": "application/json" });
			response.end(JSON.stringify(data));
		};

		try {
			if (request.headers.host !== host || (request.headers.origin && request.headers.origin !== origin))
				return send(403, { error: "Only same-origin loopback requests are allowed." });
			const url = new URL(request.url, origin);

			if (url.pathname.startsWith("/api/") || url.pathname === "/") {
				if ((request.headers["x-review-token"] || url.searchParams.get("token")) !== token)
					return send(403, { error: "Open the private URL printed by the utility." });
			}

			if (request.method === "GET" && url.pathname === "/api/state") {
				return send(200, {
					...state,
					mode,
					session: summary(),
					total: points.length,
					warnings: mode === "recorded" ? recordedWarnings(session, leaf) : state.warnings,
				});
			}

			if (request.method === "POST" && url.pathname === "/api/session") {
				if (task) return send(409, { error: "Stop the replay before loading another session." });

				const data = await bodyOf(request),
					next = parseSession(data.text),
					nextPoints = checkpoints(next);

				session = next;
				points = nextPoints;
				name = String(data.name || "Uploaded session").slice(0, 200);
				leaf = undefined;
				state = { status: "ready", completed: 0, warnings: [], error: "" };
				mode = "recorded";

				return send(200, {});
			}

			if (request.method === "POST" && url.pathname === "/api/recorded") {
				if (task) return send(409, { error: "Stop the replay first." });
				mode = "recorded";

				return send(200, {});
			}

			if (request.method === "POST" && url.pathname === "/api/stop") {
				controller?.abort();

				return send(200, {});
			}

			if (request.method === "POST" && url.pathname === "/api/replay") {
				if (task) return send(409, { error: "A replay is already running." });
				const { threshold } = await bodyOf(request);

				if (!Number.isFinite(threshold) || threshold < 0 || threshold > 1)
					return send(400, { error: "Confidence must be between 0 and 100%." });

				if (!points.length) return send(400, { error: "No assistant checkpoints exist on this branch." });
				controller = new AbortController();
				mode = "replay";
				state = { status: "starting", completed: 0, warnings: [], error: "", threshold };
				task = (async () => {
					try {
						const ctx = await context();
						controller.signal.throwIfAborted();
						await replay(points, threshold, state, controller.signal, evaluate, ctx);
					} catch (error) {
						state.status = controller.signal.aborted ? "stopped" : "error";
						state.error = controller.signal.aborted ? "" : error.message;
					} finally {
						task = undefined;
					}
				})();

				return send(202, {});
			}

			const assets = {
				"/": ["index.html", "text/html"],
				"/app.js": ["app.js", "text/javascript"],
				"/style.css": ["style.css", "text/css"],
			};

			if (request.method === "GET" && Object.hasOwn(assets, url.pathname)) {
				const [file, type] = assets[url.pathname];
				response.writeHead(200, { "Content-Type": type });
				response.end(await readFile(new URL(`./web/${file}`, import.meta.url)));

				return;
			}

			send(404, { error: "Not found." });
		} catch (error) {
			send(400, { error: error.message });
		}
	});

	await new Promise((resolve, reject) => {
		server.once("error", reject);
		server.listen(port, "127.0.0.1", resolve);
	});

	return {
		server,
		url: `http://127.0.0.1:${server.address().port}/?token=${token}`,
		close: async () => {
			controller?.abort();
			await task;
			await new Promise((resolve) => server.close(resolve));
		},
	};
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
	const args = process.argv.slice(2),
		file = args.shift();

	if (!file || file === "--help") {
		console.log(
			"Usage: node tools/ysk-backtest/server.mjs SESSION.jsonl [--port N] [--leaf ENTRY_ID] [--no-open]\nRead-only local reviewer. Recorded mode is offline; replay sends snapshots to Jev/Luna only after clicking Run replay.",
		);
		process.exit(file ? 0 : 1);
	}

	let port = 0,
		leaf,
		open = true;

	while (args.length) {
		const arg = args.shift();

		if (arg === "--no-open") open = false;
		else if (arg === "--port") {
			const value = args.shift();
			port = Number(value);

			if (!value || !Number.isInteger(port) || port < 0 || port > 65535) throw Error("Invalid port.");
		} else if (arg === "--leaf") {
			leaf = args.shift();

			if (!leaf) throw Error("--leaf requires an entry ID.");
		} else throw Error(`Unknown option: ${arg}`);
	}

	const text = await readFile(file, "utf8");

	if (Buffer.byteLength(text) > MAX_BYTES) throw Error("Session exceeds the 64 MiB limit.");
	const app = await startServer({ text, name: path.basename(file), port, leaf });
	console.log(`YSK backtest: ${app.url}\nNothing is saved. Press Ctrl+C to stop.`);

	if (open)
		execFile(process.platform === "darwin" ? "open" : "xdg-open", [app.url], (error) => {
			if (error) console.error("Could not open browser; use the URL above.");
		});

	for (const signal of ["SIGINT", "SIGTERM"])
		process.once(signal, async () => {
			await app.close();
			process.exit(0);
		});
}
