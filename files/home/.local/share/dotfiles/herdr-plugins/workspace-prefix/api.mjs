import {spawnSync} from "node:child_process";

export function call(args) {
  const options = {encoding: "utf8", timeout: 3000, stdio: ["ignore", "pipe", "pipe"]};
  const binary = process.env.HERDR_BIN_PATH || "herdr";
  let result = spawnSync(binary, args, options);
  if (binary !== "herdr" && result.error?.code === "ENOENT") {
    result = spawnSync("herdr", args, options);
  }
  if (result.status !== 0) throw new Error(result.stderr || result.error?.message || "Herdr command failed");
  return result.stdout.trim() ? JSON.parse(result.stdout).result : {};
}
