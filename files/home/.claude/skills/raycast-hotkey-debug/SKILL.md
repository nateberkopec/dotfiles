---
name: raycast-hotkey-debug
description: Debug Raycast global hotkey failures (e.g., Cmd-Space stops opening Raycast), including Secure Input detection, macOS shortcut conflicts, Raycast hotkey registration, and competing hotkey apps. Use when a user reports Raycast's shortcut stopped working or asks for root-cause analysis without restarting Raycast.
---

# Raycast Hotkey Debug

## Overview
Diagnose why Raycast's global hotkey stopped working without restarting Raycast. Focus on Secure Input, OS-level shortcut conflicts, competing hotkey utilities, and Raycast registration state.

## Debug Workflow

### 1) Confirm Raycast is running and hotkey is set
- Avoid restarting Raycast unless the user explicitly asks.
- Confirm Raycast is running:

```sh
ps -ax -o pid,comm,args | rg -i "Raycast"
```

- Confirm Raycast's configured hotkey (default should be Cmd-Space):

```sh
defaults read com.raycast.macos raycastGlobalHotkey
```

If the value is not `Command-49`, Raycast is set to a different hotkey.

### 2) Check Secure Input (common root cause)
Secure Input blocks global hotkeys while active. If an app gets stuck holding Secure Input, Raycast hotkeys will stop working until Secure Input is released.

```sh
ioreg -l -w 0 | rg -i "SecureInput|kCGSSessionSecureInputPID"
```

If you see `kCGSSessionSecureInputPID=<pid>`, identify the app:

```sh
ps -p <pid> -o pid,comm,args
```

Actions:
- Close or restart the app holding Secure Input.
- If this repeats, update or report the app (browser password prompts and password managers are frequent culprits).

### 3) Check macOS shortcut conflicts (Spotlight / Input Sources)
Spotlight or Input Source shortcuts can take Cmd-Space or related keys back. Confirm symbolic hotkeys:

```sh
defaults export com.apple.symbolichotkeys - > /tmp/symbolichotkeys.plist
/usr/bin/plutil -p /tmp/symbolichotkeys.plist | rg -n -C 2 "\b(60|61|64|65)\b|enabled"
```

Common mappings:
- 64: Spotlight search (Cmd-Space)
- 65: Finder search window (Cmd-Option-Space)
- 60: Select next input source (Control-Space)
- 61: Select previous input source (Control-Option-Space)

If 64 is enabled, Spotlight is likely reclaiming Cmd-Space. Disable or remap in System Settings -> Keyboard -> Keyboard Shortcuts.

### 4) Look for competing hotkey managers
Common conflicts: Alfred, Keyboard Maestro, BetterTouchTool, Karabiner, Hammerspoon, Rectangle, Magnet, TextExpander.

```sh
ps -ax -o pid,comm,args | rg -i "Alfred|Karabiner|Hammerspoon|BetterTouchTool|Magnet|Rectangle|Keyboard Maestro|TextExpander|hotkey"
```

If present, inspect their global hotkeys and disable any overlap with Cmd-Space.

### 5) Inspect Raycast logs for registration failures
Raycast doesn't always log hotkey issues, but check system logs for hints:

```sh
bash -lc 'log show --style syslog --predicate "(process == \"Raycast\" OR process == \"Raycast Helper\" OR process == \"RaycastAppIntents\")" --last 1h | rg -i "hotkey|shortcut|register|secure|input"'
```

### 6) Provide a root-cause summary and fix plan
Common fixes to recommend:
- Secure Input app is holding the lock -> close/update that app.
- Spotlight or Input Source hotkeys re-enabled -> disable or remap.
- Competing hotkey utility -> remove the conflict.
- Provide a backup Raycast hotkey so the user can open it even if Cmd-Space is blocked.

If the same Secure Input holder keeps showing up, that is the most likely permanent fix target.

## Notes
- Do not restart Raycast unless the user explicitly requests it.
- If the issue is intermittent, ask when it happens (after sleep, after unlocking, after entering passwords) and correlate with Secure Input or hotkey conflicts.
