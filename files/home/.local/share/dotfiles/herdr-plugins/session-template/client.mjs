import { spawn } from "node:child_process";
import { mkdirSync, openSync, writeSync } from "node:fs";
import { constants } from "node:os";
import { join } from "node:path";

const [session, ...args] = process.argv.slice(2);
const state = process.env.XDG_STATE_HOME;
mkdirSync(state, { recursive: true });
const log = openSync(join(state, "template-sync.log"), "a");
const env = { ...process.env };
for (const key of Object.keys(env)) {
	if (key.startsWith("HERDR_")) delete env[key];
}
const client = spawn("herdr", args, { stdio: "inherit" });
const timer = setInterval(() => {
	const action = spawn(
		"herdr",
		["--session", session, "plugin", "action", "invoke", "sync", "--plugin", "dotfiles.session-template"],
		{
			env,
			stdio: ["ignore", "ignore", log],
		},
	);
	action.on("error", (error) => writeSync(log, `${error.message}\n`));
	action.unref();
}, 300000);

process.on("SIGINT", () => {});
for (const signal of ["SIGTERM", "SIGHUP"]) {
	process.on(signal, () => {
		clearInterval(timer);
		client.kill(signal);
	});
}
client.on("error", (error) => {
	console.error(`herdr: ${error.message}`);
	process.exitCode = 127;
	clearInterval(timer);
});
client.on("exit", (code, signal) => {
	clearInterval(timer);
	process.exitCode = code ?? 128 + constants.signals[signal];
});
