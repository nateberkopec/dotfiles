import {existsSync} from "node:fs";

export async function sync(template, {list, create, move, log}) {
  const existing = list();
  const ordered = [];
  for (const workspace of template) {
    if (!existsSync(workspace.cwd)) {
      log(`skipping ${workspace.label}: missing directory ${workspace.cwd}`);
      continue;
    }
    const matches = existing.filter(space => space.label === workspace.label);
    if (matches.length > 1) {
      log(`skipping ${workspace.label}: ${matches.length} workspaces share that label`);
      continue;
    }
    if (matches.length === 1) {
      ordered.push(matches[0].workspace_id);
      continue;
    }
    const created = create(workspace);
    existing.push(created);
    ordered.push(created.workspace_id);
    log(`created ${workspace.label}`);
  }
  await reorder(existing.map(space => space.workspace_id), ordered, move, log);
}

async function reorder(current, ordered, move, log) {
  for (const [index, id] of ordered.entries()) {
    if (current[index] === id) continue;
    current.splice(current.indexOf(id), 1);
    current.splice(index, 0, id);
    await move(id, index);
    log(`moved ${id} to position ${index + 1}`);
  }
}
