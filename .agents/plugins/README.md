# Skills in ChatGPT Work

The `nate-dotfiles` marketplace packages the existing
`files/home/.claude/skills/` directory as the `nate-skills` plugin. There is no
export step or second copy of the skill sources to maintain.

## Install on a Mac

After the marketplace changes merge to `main`, run in fish:

```fish
codex plugin marketplace add nateberkopec/dotfiles --ref main
codex plugin add nate-skills@nate-dotfiles
```

Restart the ChatGPT desktop app, select Work, and open Plugins. Confirm that
Nate's Dotfiles / nate-skills appears and is enabled. Start a new Work chat and
use `@` to select a bundled skill, such as grilling.

This installs through the local Codex plugin system used by the desktop app.
It does not publish the plugin to ChatGPT's public directory or establish that
it is available in cloud Work on the web or mobile. Personal Pro account
availability must be verified in the app.

## Automatic updates

The Git marketplace tracks `main`. Codex 0.154.0 refreshes configured Git
marketplaces in its background startup tasks and reinstalls configured plugins
when the source revision changes. This includes skill edits without a plugin
version bump. No export job, GitHub Action, or separate sync daemon is needed.

Merge skill changes through a PR as usual. Quit and reopen the ChatGPT desktop
app to let its plugin host check for updates, then start a new Work chat. This
is startup refresh, not a guaranteed periodic background sync. Verify this in
the installed desktop build before relying on it unattended.

To force a refresh:

```fish
codex plugin marketplace upgrade nate-dotfiles
```

After an external CLI refresh, restart ChatGPT so its running process reloads
the installed files. Check the configured source and installed plugin with:

```fish
codex plugin marketplace list
codex plugin list --marketplace nate-dotfiles
```

The local checkout does not need to be pulled for this path: Codex maintains
its own GitHub marketplace snapshot. Keep the configured ref on `main` for
normal use; a commit pin would prevent receiving subsequent changes.

## Source and compatibility

The marketplace points at `files/home/.claude`, whose root `plugin.json`
discovers the existing `skills/` directory. Supporting resources and licenses
remain alongside the skills. The plugin does not declare MCP servers or hooks.

Installation makes the instructions available; it does not supply tools,
credentials, runtimes, or local filesystem access required by individual
skills. Start with an instruction-only workflow to verify the installation.
Claude-specific skill metadata may not have the same behavior in Work.

## References

- [Plugin packaging and marketplaces](https://developers.openai.com/plugins/build/plugins)
- [Using plugins in Work](https://developers.openai.com/codex/plugins)
- [Codex 0.154.0 startup refresh and cache reinstall](https://github.com/openai/codex/blob/rust-v0.154.0/codex-rs/core-plugins/src/manager.rs#L2745-L2955)
- [Workspace-admin GitHub sync](https://help.openai.com/en/articles/20001504-importing-and-syncing-plugin-marketplaces-from-github)
