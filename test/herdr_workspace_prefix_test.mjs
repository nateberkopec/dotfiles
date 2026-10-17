import assert from "node:assert/strict";
import {dirname, join} from "node:path";
import {fileURLToPath} from "node:url";
import {test} from "node:test";
import {call} from "../files/home/.local/share/dotfiles/herdr-plugins/workspace-prefix/api.mjs";
import {agentTitle, refresh} from "../files/home/.local/share/dotfiles/herdr-plugins/workspace-prefix/prefix.mjs";

const fixtures = fileURLToPath(new URL("./fixtures/herdr_workspace_prefix", import.meta.url));

function environment(values, run) {
  const previous = {...process.env};
  Object.assign(process.env, values);
  try {
    run();
  } finally {
    process.env = previous;
  }
}

test("falls back to PATH when the reported Herdr binary no longer exists", () => {
  environment({HERDR_BIN_PATH: join(fixtures, "missing-herdr"), PATH: `${fixtures}:${dirname(process.execPath)}:${process.env.PATH}`}, () => {
    assert.deepEqual(call(["agent", "list"]), {agents: []});
  });
});

test("does not hide errors from an existing reported binary", () => {
  environment({HERDR_BIN_PATH: process.execPath}, () => {
    assert.throws(() => call(["--invalid-herdr-test-option"]), /bad option/);
  });
});

test("uses the first three non-whitespace characters, uppercased", () => {
  for (const [label, prefix] of [
    ["Level Software, Inc.", "LEV"], ["AdQuick", "ADQ"], ["Beehiiv", "BEE"],
    ["ez Home Search, Inc.", "EZH"], ["Speedshop", "SPE"], [" e\tz\n H", "EZH"],
    ["Å 猫 B", "Å猫B"], ["AB", "AB"],
  ]) {
    assert.equal(agentTitle({label}, {terminal_title_stripped: "π · Task"}), `[${prefix}] Task`);
  }
});

test("prefers live titles over metadata and handles other agents", () => {
  assert.equal(agentTitle({label: "Level"}, {terminal_title_stripped: "New task", title: "Old task"}), "[LEV] New task");
  assert.equal(agentTitle({label: "Level"}, {title: "Task"}), "[LEV] Task");
  assert.equal(agentTitle({label: "Speedshop"}, {terminal_title_stripped: "π - client_notes"}), "[SPE] client_notes");
  assert.equal(agentTitle({label: "Level"}, {agent: "pi"}), "[LEV] pi");
  assert.equal(agentTitle({label: "Level"}, {title: "x".repeat(100)}).length, 80);
});

test("refresh follows workspace moves and renames without changing sessions", () => {
  const writes = [];
  const workspace = {workspace_id: "w1", label: "Level"};
  const agent = {workspace_id: "w1", pane_id: "w1:p1", terminal_title_stripped: "π · Task", tokens: {}};
  const call = args => {
    if (args[0] === "workspace") return {workspaces: [workspace]};
    if (args[0] === "agent") return {agents: [agent]};
    writes.push(args);
    agent.tokens.workspace_agent_title = args.at(-1).split("=").slice(1).join("=");
    return {};
  };
  refresh(call);
  assert.equal(writes.length, 1);
  assert.equal(writes[0].at(-1), "workspace_agent_title=[LEV] Task");
  refresh(call);
  assert.equal(writes.length, 1);
  workspace.label = "Speedshop";
  refresh(call);
  assert.equal(writes[1].at(-1), "workspace_agent_title=[SPE] Task");
  workspace.workspace_id = agent.workspace_id = "w2";
  agent.pane_id = "w2:p1";
  agent.terminal_title_stripped = "π · New task";
  refresh(call);
  assert.equal(writes[2][2], "w2:p1");
  assert.equal(writes[2].at(-1), "workspace_agent_title=[SPE] New task");
  assert.ok(writes.every(args => args[0] === "pane" && args[1] === "report-metadata"));
  assert.ok(writes.every(args => args.includes("plugin:dotfiles.workspace-prefix")));
});

test("ignores agents without a named workspace", () => {
  refresh(args => {
    if (args[0] === "workspace") return {workspaces: []};
    if (args[0] === "agent") return {agents: [{workspace_id: "missing", agent: "pi"}]};
    assert.fail("must not write metadata");
  });
});
