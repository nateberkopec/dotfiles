export function agentTitle(workspace, agent) {
  const prefix = Array.from(workspace.label.replace(/\s/gu, "")).slice(0, 3).join("").toUpperCase();
  const title = (agent.terminal_title_stripped || agent.title || agent.agent)
    .replace(/^π\s*[·-]\s*/u, "");
  return `[${prefix}] ${title}`.slice(0, 80);
}

export function refresh(call) {
  const seq = String(Date.now());
  const {workspaces} = call(["workspace", "list"]);
  const {agents} = call(["agent", "list"]);
  for (const agent of agents) {
    const workspace = workspaces.find(space => space.workspace_id === agent.workspace_id);
    if (!workspace?.label) continue;
    const title = agentTitle(workspace, agent);
    if (agent.tokens?.workspace_agent_title === title) continue;
    call(["pane", "report-metadata", agent.pane_id,
      "--source", "plugin:dotfiles.workspace-prefix",
      "--seq", seq,
      "--token", `workspace_agent_title=${title}`]);
  }
}
