import { spawn, spawnSync } from "node:child_process";
import { mkdirSync, openSync, closeSync, writeSync } from "node:fs";
import { constants, homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const [session, ...args] = process.argv.slice(2);
const state = process.env.XDG_STATE_HOME || join(homedir(), ".local", "state", "herdr-sessions", session);
mkdirSync(state, { recursive: true });
const log = openSync(join(state, "template-sync.log"), "a");
const env = { ...process.env };
for (const key of Object.keys(env)) {
	if (key.startsWith("HERDR_")) delete env[key];
}
let syncing;
let stopped = false;
const client = spawn("herdr", args, { stdio: "inherit" });
const timer = setInterval(sync, 300000);
const report = (message) => writeSync(log, `session-template[${session}]: ${message}\n`);

function sync() {
	if (stopped || syncing) return;
	try {
		const options = { env, encoding: "utf8", timeout: 10000, stdio: ["ignore", "pipe", "pipe"] };
		const call = (args) => {
			const result = spawnSync("herdr", ["--session", session, ...args], options);
			if (result.status !== 0)
				throw new Error(result.stderr?.trim() || result.error?.message || "Herdr command failed");
			return result.stdout.trim();
		};
		const { socket } = JSON.parse(call(["status", "server", "--json"]));
		const config = call(["plugin", "config-dir", "dotfiles.session-template"]);
		const script = fileURLToPath(new URL("index.mjs", import.meta.url));
		const lock = join(dirname(socket), "template-sync.lock");
		const command = process.platform === "darwin" ? "lockf" : "flock";
		const flags = process.platform === "darwin" ? ["-s", "-k", "-t", "0"] : ["-n", "-E", "75"];
		syncing = spawn(command, [...flags, lock, process.execPath, script], {
			env: {
				...env,
				HERDR_ENV: "1",
				HERDR_SOCKET_PATH: socket,
				HERDR_BIN_PATH: "herdr",
				HERDR_PLUGIN_CONFIG_DIR: config,
			},
			detached: true,
			stdio: ["ignore", log, log],
		});
		syncing.on("error", (error) => report(error.message));
		syncing.on("close", (code) => {
			if (!stopped && code !== 0 && code !== 75) report(`sync exited with status ${code}`);
			syncing = undefined;
		});
	} catch (error) {
		report(error.message);
	}
}

function stop() {
	stopped = true;
	clearInterval(timer);
	if (syncing?.pid) {
		try {
			process.kill(-syncing.pid, "SIGTERM");
		} catch (error) {
			if (error.code !== "ESRCH") throw error;
		}
	}
}

process.on("SIGINT", () => {});
for (const signal of ["SIGTERM", "SIGHUP"]) {
	process.on(signal, () => {
		stop();
		client.kill(signal);
	});
}
client.on("error", (error) => {
	console.error(`herdr: ${error.message}`);
	process.exitCode = 127;
	stop();
});
client.on("exit", (code, signal) => {
	stop();
	process.exitCode = code ?? 128 + constants.signals[signal];
});
process.on("exit", () => closeSync(log));
