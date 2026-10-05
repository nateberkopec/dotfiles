# Pi workflow status in Herdr

The dotfiles-owned `herdr-status` extension replaces Herdr's managed Pi status
extension. Personal Pi settings exclude `extensions/herdr-agent-state.ts` from
loading, even if Herdr reinstalls that file. Keep the managed integration
installed; only its status extension is excluded.

The replacement reports session identity and lifecycle state under `herdr:pi`,
so Herdr retains its native dots, completion tracking, notifications, and waits.
It runs only in the owning Herdr TUI process, not headless subagent processes.
It does not change pi-subagents, workspace names, or sidebar labels.

## Precedence

1. Human attention or an open user-facing Pi dialog: red `blocked`.
2. Parent activity or delegated background activity: yellow `working`.
3. Neither: `idle`. Herdr displays unseen completions as teal `done` and seen
   idle agents as green hollow dots.

The extension consumes counted `herdr:busy` overlays and reconciles active
subagents through pi-subagents' fleet-status RPC at session start and parent
settlement. Fleet-status errors are not treated as proof that children finished.
Human-attention requests survive reload, branch navigation, and background agent
wake-ups. They clear on user input, not extension-injected input.

## Asking the human

The parent calls `human_attention` with a short, non-sensitive reason before
asking a question in its final reply and returning control. This marks the
workflow red even while children remain active. The reason is stored in the
session branch and reported to Herdr; do not include credentials or private
prompt content.

Do not use this tool for ordinary background waits or child-to-parent supervisor
requests. Problems the parent can resolve do not require human attention.
User-facing Pi dialogs are tracked automatically through `ui_prompt_start` and
`ui_prompt_end`.

Use `/human-attention` to show the current explicit request, or
`/human-attention clear` to dismiss it without sending a model message.
Ordinary questions in assistant prose cannot be classified reliably; the parent
must use the tool when it requires human intervention.

## pi-subagents release boundary

The pi-subagents pin remains unchanged. Its current `herdr:blocked` events are
still honored; this extension does not filter or patch them. Upstream PR
[nicobailon/pi-subagents#2703](https://github.com/nicobailon/pi-subagents/pull/2703)
removes child-attention blocked overlays. After installing a release containing
that change and restarting Pi, child attention no longer creates human alerts
through that bridge. The busy-event consumer here fixes the independent idle-dot
problem tracked in
[nicobailon/pi-subagents#1786](https://github.com/nicobailon/pi-subagents/issues/1786).

Converging the live machine and reloading existing sessions are separate actions;
changing this repository does not update running processes.
