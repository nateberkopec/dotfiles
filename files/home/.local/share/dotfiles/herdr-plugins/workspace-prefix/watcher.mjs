import {createHash} from "node:crypto";
import {mkdirSync, readFileSync, rmSync, writeFileSync} from "node:fs";
import {createConnection} from "node:net";
import {join} from "node:path";
import {call} from "./api.mjs";
import {refresh} from "./prefix.mjs";

const socketPath = process.env.HERDR_SOCKET_PATH;
const key = createHash("sha256").update(socketPath).digest("hex").slice(0, 16);
const lock = join(process.env.HERDR_PLUGIN_STATE_DIR, `watcher-${key}`);
try {
  mkdirSync(lock);
} catch (error) {
  if (error.code !== "EEXIST") throw error;
  try {
    process.kill(Number(readFileSync(join(lock, "pid"), "utf8")), 0);
    process.exit(0);
  } catch (error) {
    if (error.code === "ENOENT") process.exit(0);
    if (error.code !== "ESRCH") throw error;
  }
  rmSync(lock, {recursive: true});
  mkdirSync(lock);
}
writeFileSync(join(lock, "pid"), String(process.pid));
process.on("exit", () => rmSync(lock, {recursive: true, force: true}));
process.on("SIGTERM", () => process.exit(0));
process.on("SIGINT", () => process.exit(0));

function enabled() {
  return call(["plugin", "list", "--plugin", "dotfiles.workspace-prefix", "--json"])
    .plugins?.some(plugin => plugin.enabled);
}

let timer;
function reconcile() {
  try {
    if (!enabled()) process.exit(0);
    refresh(call);
  } catch (error) {
    console.error(error.message);
  }
}
function invalidate() {
  if (timer) return;
  timer = setTimeout(() => {
    timer = undefined;
    reconcile();
  }, 100);
}

function subscribe() {
  const socket = createConnection(socketPath);
  let buffer = "";
  let recover = false;
  socket.setEncoding("utf8");
  socket.on("connect", () => socket.write(JSON.stringify({
    id: "workspace-prefix", method: "events.subscribe", params: {subscriptions:
      ["workspace.renamed", "pane.moved", "pane.updated", "pane.agent_detected"]
        .map(type => ({type})),
    },
  }) + "\n"));
  socket.on("data", data => {
    buffer += data;
    let end;
    while ((end = buffer.indexOf("\n")) !== -1) {
      const message = JSON.parse(buffer.slice(0, end));
      buffer = buffer.slice(end + 1);
      if (message.error) {
        console.error(message.error);
        recover = message.error.code === "events_lost";
        socket.destroy();
        return;
      }
      invalidate();
    }
  });
  socket.on("error", error => console.error(error.message));
  socket.on("close", () => {
    if (recover) setTimeout(subscribe, 250);
    else process.exit(0);
  });
}

subscribe();
setInterval(() => {
  try {
    if (!enabled()) process.exit(0);
  } catch {
    process.exit(0);
  }
}, 10000);
