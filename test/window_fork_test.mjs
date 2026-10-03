import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import windowFork from "../files/home/.pi/agent/extensions/window-fork.ts";

test("forks the committed branch into a new Ghostty window with an optional prompt", async (t) => {
  if (process.platform !== "darwin") return t.skip("Ghostty AppleScript requires macOS");

  const directory = await mkdtemp(join(tmpdir(), "pi-window-fork-"));
  const sessionFile = join(directory, "original.jsonl");
  const branch = [{ type: "message", id: "entry-1", message: { role: "user", content: "hello" } }];
  let command;
  let invocation;
  const pi = {
    registerCommand: (name, definition) => { assert.equal(name, "window-fork"); command = definition; },
    exec: async (...args) => { invocation = args; return { code: 0 }; },
  };
  windowFork(pi);
  assert.ok(command);
  const notifications = [];
  await command.handler("explore another approach", {
    cwd: directory,
    isIdle: () => true,
    sessionManager: {
      getSessionFile: () => sessionFile,
      getBranch: () => branch,
      getHeader: () => ({ version: 3, cwd: directory }),
    },
    ui: { notify: (...args) => notifications.push(args) },
  });

  const [executable, args] = invocation;
  assert.equal(executable, "osascript");
  assert.match(args[1], /new window with configuration cfg/);
  assert.doesNotMatch(args[1], /split targetTerminal/);
  assert.equal(args[3], directory);
  const startup = args[4];
  const forkPath = startup.match(/'--session' '([^']+)'/)?.[1];
  assert.ok(forkPath, startup);
  assert.match(startup, /'--' 'explore another approach'\n$/);
  const [header, entry] = (await readFile(forkPath, "utf8")).trim().split("\n").map(JSON.parse);
  assert.equal(header.parentSession, sessionFile);
  assert.equal(header.cwd, directory);
  assert.deepEqual(entry, branch[0]);
  assert.match(notifications[0][0], /new Ghostty window/);
});
