import {call, request} from "./herdr.mjs";
import {sync} from "./sync.mjs";
import {readTemplate, sessionName} from "./template.mjs";

const session = sessionName(process.env.HERDR_SOCKET_PATH);
const template = readTemplate(process.env.HERDR_PLUGIN_CONFIG_DIR, session);

if (template) {
  await sync(template, {
    list: () => call(["workspace", "list"]).workspaces,
    create: ({label, cwd}) => call(["workspace", "create", "--label", label, "--cwd", cwd, "--no-focus"]).workspace,
    move: (workspace_id, insert_index) => request("workspace.move", {workspace_id, insert_index}),
    log: message => console.log(`session-template[${session}]: ${message}`),
  });
}
