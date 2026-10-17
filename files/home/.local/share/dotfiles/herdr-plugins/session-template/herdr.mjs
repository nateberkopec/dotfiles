import {spawnSync} from "node:child_process";
import {createConnection} from "node:net";

export function call(args) {
  const options = {encoding: "utf8", timeout: 10000, stdio: ["ignore", "pipe", "pipe"]};
  const binary = process.env.HERDR_BIN_PATH || "herdr";
  let result = spawnSync(binary, args, options);
  if (binary !== "herdr" && result.error?.code === "ENOENT") {
    result = spawnSync("herdr", args, options);
  }
  if (result.status !== 0) {
    throw new Error(result.stderr?.trim() || result.error?.message || `herdr ${args.join(" ")} failed`);
  }
  return JSON.parse(result.stdout).result;
}

export function request(method, params) {
  return new Promise((resolve, reject) => {
    const socket = createConnection(process.env.HERDR_SOCKET_PATH);
    const timer = setTimeout(() => finish(new Error(`${method} timed out`)), 5000);
    let buffer = "";
    const finish = (error, result) => {
      clearTimeout(timer);
      socket.destroy();
      if (error) reject(error);
      else resolve(result);
    };
    socket.setEncoding("utf8");
    socket.on("connect", () => socket.write(`${JSON.stringify({id: `session-template:${method}`, method, params})}\n`));
    socket.on("data", chunk => {
      buffer += chunk;
      const end = buffer.indexOf("\n");
      if (end === -1) return;
      const response = JSON.parse(buffer.slice(0, end));
      if (response.error) finish(new Error(JSON.stringify(response.error)));
      else finish(undefined, response.result);
    });
    socket.on("error", finish);
  });
}
