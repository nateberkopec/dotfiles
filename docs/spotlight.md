# Spotlight management

Dotfiles manages Spotlight's **volume indexing policy** with a root-owned controller. It disables indexing on battery, enables it on AC, and lets a temporary pause override either state. The LaunchDaemon never executes a user-writable script; `dotf run` installs its executable as root, and interactive changes require `sudo` authentication.

```sh
mise run spotlight:status
mise run spotlight:pause -- 24h
mise run spotlight:resume
mise run spotlight:audit
```

`resume` clears the pause and reapplies the power policy, so it keeps indexing disabled when the Mac is on battery. Expired pauses are removed automatically. Pause state is root-owned under `/var/db/dotfiles-spotlight`.

## Settings that remain manual

Apple documents no supported command-line setter for folder exclusions. Add these in **System Settings > Spotlight > Search Privacy**:

- `~/Documents/Code.nosync`
- `~/src`

The desired paths remain declared in `config/config.yml`, and `spotlight:audit` prints both that declaration and Spotlight's effective volume configuration. The effective `Exclusions` array, not the user defaults preference or an empty `mdfind` result, determines whether the setup is complete. Grant the terminal Full Disk Access only if macOS reports a permission error while reading the configuration.

Spotlight result-category controls also remain in System Settings. `mdutil -i off` controls filesystem volume indexing; it does not stop app-provided CoreSpotlight processing such as Mail, Messages, or Notes indexing.
