import {spawn} from "node:child_process";
import {openSync} from "node:fs";
import {join} from "node:path";
import {fileURLToPath} from "node:url";
import {call} from "./api.mjs";
import {refresh} from "./prefix.mjs";

refresh(call);
const log = openSync(join(process.env.HERDR_PLUGIN_STATE_DIR, "watcher.log"), "a", 0o600);
const child = spawn(process.execPath, [fileURLToPath(new URL("./watcher.mjs", import.meta.url))], {
  detached: true, stdio: ["ignore", log, log],
});
child.unref();
