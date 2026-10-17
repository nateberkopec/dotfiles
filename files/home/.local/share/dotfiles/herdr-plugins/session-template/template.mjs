import {spawnSync} from "node:child_process";
import {accessSync, constants, existsSync, readFileSync} from "node:fs";
import {homedir} from "node:os";
import {join} from "node:path";

export function sessionName(socketPath = "") {
  return /\/sessions\/([^/]+)\/herdr\.sock$/u.exec(socketPath)?.[1] ?? "default";
}

export function readTemplate(directory, session) {
  const json = join(directory, `${session}.json`);
  if (existsSync(json)) return parse(readFileSync(json, "utf8"), json);
  const source = join(directory, session);
  if (!existsSync(source)) return undefined;
  if (!executable(source)) return parse(readFileSync(source, "utf8"), source);
  const result = spawnSync(source, [], {encoding: "utf8", timeout: 60000, stdio: ["ignore", "pipe", "pipe"]});
  if (result.status !== 0) {
    throw new Error(`${source} failed: ${result.stderr?.trim() || result.error?.message}`);
  }
  return parse(result.stdout, source);
}

function executable(path) {
  try {
    accessSync(path, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function parse(text, source) {
  const {workspaces} = JSON.parse(text);
  if (!Array.isArray(workspaces)) throw new Error(`${source}: "workspaces" must be an array`);
  const labels = new Set();
  return workspaces.map(({label, cwd}) => {
    if (typeof label !== "string" || !label.trim()) throw new Error(`${source}: every workspace needs a label`);
    if (labels.has(label)) throw new Error(`${source}: duplicate label ${JSON.stringify(label)}`);
    labels.add(label);
    if (typeof cwd !== "string" || !cwd) throw new Error(`${source}: ${label} needs a cwd`);
    return {label, cwd: cwd.replace(/^~(?=$|\/)/u, homedir())};
  });
}
