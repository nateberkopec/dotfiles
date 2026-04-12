---
name: aerospace
description: This skill should be used when users want to manage windows on macOS using AeroSpace, an i3-like tiling window manager. Use for both ad-hoc window management requests ("move this window to workspace 2", "tile these windows") and scripting tasks (writing shell scripts, automations, or config modifications). Use when users mention "aerospace", "window management", "tiling", "workspaces", or ask about managing windows on macOS.
---

# AeroSpace Window Management

## Version Check

This skill was created with AeroSpace version **0.20.2-Beta**. Before executing commands or writing scripts, verify the installed version:

```fish
aerospace --version
```

If the version differs significantly, consult `aerospace --help` and individual command help to verify syntax hasn't changed.

## Overview

AeroSpace is an i3-like tiling window manager for macOS. It provides:

- Virtual workspaces (independent of macOS Spaces)
- Tree-based window tiling (tiles and accordion layouts)
- Scriptable CLI for automation
- TOML-based configuration

The `aerospace` CLI is the primary interface for both interactive use and scripting.

## Core Concepts

### The Tree Model

AeroSpace organizes windows in a tree structure inspired by i3:

- Each **workspace** has a root container
- **Containers** hold children (windows or other containers)
- **Windows** are leaf nodes
- Each container has:
  - **Layout**: `tiles` or `accordion`
  - **Orientation**: `horizontal` or `vertical`

Combined layouts: `h_tiles`, `v_tiles`, `h_accordion`, `v_accordion`

### Workspaces

- Virtual workspaces emulate i3 behavior without macOS Spaces limitations
- Workspace names can be any string (commonly: 1-9, A-Z, or descriptive names)
- Each monitor shows one workspace at a time
- Inactive workspace windows are hidden off-screen
- Pool of workspaces is shared across all monitors

### Monitors

- Workspaces can be assigned to specific monitors
- Use `main`, `secondary`, monitor index (1-based), or regex patterns
- Focus follows workspace assignment

## Getting Command Help

**IMPORTANT**: Always use help commands to get exact syntax. This skill teaches concepts; the CLI teaches exact usage.

```fish
# List all commands
aerospace --help

# Get help for any command
aerospace <command> --help

# Examples
aerospace focus --help
aerospace list-windows --help
aerospace workspace --help
```

## Common Commands by Category

### Navigation (Focus)

```fish
# Focus window in direction
aerospace focus left|down|up|right

# Focus by window ID
aerospace focus --window-id <id>

# Focus next/prev in depth-first order
aerospace focus dfs-next|dfs-prev
```

### Window Movement

```fish
# Move focused window in direction
aerospace move left|down|up|right

# Move window to workspace
aerospace move-node-to-workspace <workspace>
aerospace move-node-to-workspace next|prev

# Move window to monitor
aerospace move-node-to-monitor left|right|next|prev
```

### Workspace Management

```fish
# Switch to workspace
aerospace workspace <name>
aerospace workspace next|prev

# Move workspace to different monitor
aerospace move-workspace-to-monitor next|prev
```

### Layout Control

```fish
# Change layout (multiple args = find first non-current and apply)
aerospace layout tiles|accordion
aerospace layout horizontal|vertical
aerospace layout h_tiles|v_tiles|h_accordion|v_accordion
aerospace layout floating|tiling

# Toggle fullscreen
aerospace fullscreen
aerospace fullscreen on|off
```

### Tree Manipulation

```fish
# Join focused window with neighbor under common parent
aerospace join-with left|down|up|right

# Resize windows
aerospace resize smart|width|height +|-<pixels>

# Balance all window sizes
aerospace balance-sizes

# Flatten workspace tree (reset splits)
aerospace flatten-workspace-tree
```

### Query Commands (For Scripting)

```fish
# List windows
aerospace list-windows --workspace focused
aerospace list-windows --all
aerospace list-windows --monitor focused
aerospace list-windows --format '%{window-id} %{app-name}'

# List workspaces
aerospace list-workspaces --all
aerospace list-workspaces --monitor focused --empty no

# List monitors
aerospace list-monitors

# List running apps (useful for on-window-detected)
aerospace list-apps

# Get config values
aerospace config --get mode.main.binding --json
aerospace config --config-path
```

## Output Formatting

Query commands support `--format` with interpolation:

```fish
# Common variables
%{window-id}      # Window unique ID
%{window-title}   # Window title
%{app-name}       # Application name
%{app-bundle-id}  # Application bundle ID (e.g., com.apple.Safari)
%{workspace}      # Workspace name
%{monitor-id}     # Monitor index

# JSON output for scripting
aerospace list-windows --workspace focused --json
```

## Scripting Patterns

### Pattern: Find and Focus Window by App

```fish
# Focus Safari window
set window_id (aerospace list-windows --all --format '%{window-id} %{app-name}' | grep Safari | head -1 | cut -d' ' -f1)
and aerospace focus --window-id $window_id
```

### Pattern: Move App to Specific Workspace

```fish
# Move all Chrome windows to workspace W
for id in (aerospace list-windows --all --app-bundle-id com.google.Chrome --format '%{window-id}')
    aerospace move-node-to-workspace --window-id $id W
end
```

### Pattern: Cycle Through Non-Empty Workspaces

```fish
aerospace list-workspaces --monitor focused --empty no | aerospace workspace next
```

### Pattern: Current Workspace Info

```fish
set current_ws (aerospace list-workspaces --focused)
set window_count (aerospace list-windows --workspace focused --count)
echo "Workspace $current_ws has $window_count windows"
```

## Configuration Overview

Config location: `~/.aerospace.toml` or `~/.config/aerospace/aerospace.toml`

### Key Configuration Concepts

**Binding Modes**: Like vim modes. `main` is default. Switch modes with `mode <mode-name>`.

```toml
[mode.main.binding]
    alt-h = 'focus left'
    alt-r = 'mode resize'

[mode.resize.binding]
    minus = 'resize smart -50'
    esc = 'mode main'
```

**on-window-detected Callbacks**: Auto-assign apps to workspaces:

```toml
[[on-window-detected]]
    if.app-id = 'com.apple.Safari'
    run = 'move-node-to-workspace W'
```

**Workspace-to-Monitor Assignment**:

```toml
[workspace-to-monitor-force-assignment]
    1 = 'main'
    2 = 'secondary'
```

**exec-on-workspace-change**: For bar integration (e.g., Sketchybar):

```toml
exec-on-workspace-change = ['/bin/bash', '-c',
    'sketchybar --trigger aerospace_workspace_change FOCUSED=$AEROSPACE_FOCUSED_WORKSPACE'
]
```

### Getting App Bundle IDs

For `on-window-detected`, you need bundle IDs:

```fish
# List all running apps with bundle IDs
aerospace list-apps

# Or use mdls
mdls -name kMDItemCFBundleIdentifier -r /Applications/Safari.app
```

## Ad-Hoc Window Management Tasks

When users ask for window management tasks, translate to aerospace commands:

| User Request | Command |
|-------------|---------|
| "Move this window right" | `aerospace move right` |
| "Focus the window above" | `aerospace focus up` |
| "Send to workspace 3" | `aerospace move-node-to-workspace 3` |
| "Go to workspace mail" | `aerospace workspace mail` |
| "Make this fullscreen" | `aerospace fullscreen` |
| "Float this window" | `aerospace layout floating` |
| "Tile horizontally" | `aerospace layout h_tiles` |
| "Stack windows" | `aerospace layout v_accordion` |
| "Swap with window on right" | `aerospace move right` (move swaps in tiles) |
| "Resize larger" | `aerospace resize smart +50` |
| "Which workspace am I on?" | `aerospace list-workspaces --focused` |
| "What windows are here?" | `aerospace list-windows --workspace focused` |

## Debugging

```fish
# Debug window detection issues
aerospace debug-windows

# Check loaded config path
aerospace config --config-path

# List current binding modes
aerospace list-modes

# Show exec environment variables
aerospace list-exec-env-vars

# Reload config after changes
aerospace reload-config
```

## Common Issues

1. **Keys not working**: Check for conflicts with other global hotkey apps (skhd, Karabiner, Raycast)

2. **Windows not tiling**: Some windows are detected as dialogs. Use `on-window-detected` with `run = 'layout tiling'` to force

3. **Multi-monitor issues**: Disable "Displays have separate Spaces" in System Settings for better stability

4. **Hidden windows visible**: Arrange monitors so every monitor has free space in bottom corners

## Resources

- Official docs: https://nikitabobko.github.io/AeroSpace/
- Man pages: `man aerospace-<command>` (if installed via Homebrew)
- Default config: `/Applications/AeroSpace.app/Contents/Resources/default-config.toml`
- Bootstrap config: `cp /Applications/AeroSpace.app/Contents/Resources/default-config.toml ~/.aerospace.toml`
