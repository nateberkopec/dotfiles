class Dotfiles::Migration::ReplaceIceWithThaw < Dotfiles::Migration
  VERSION = 202609290001

  macos_only

  def up
    execute(command("osascript", "-e", 'tell application id "com.jordanbaird.Ice" to quit')) if command_succeeds?(command("pgrep", "-x", "Ice"))
    execute(command(
      "osascript",
      "-e", 'tell application "System Events"',
      "-e", 'if exists login item "Ice" then delete login item "Ice"',
      "-e", "end tell"
    ))
    return unless command_exists?("brew") && command_succeeds?(homebrew_command("list", "--cask", "jordanbaird-ice"))

    # Keep Ice's defaults domain: Thaw offers to import it during first launch.
    execute(homebrew_command("uninstall", "--cask", "jordanbaird-ice"))
  end

  def down
    raise NotImplementedError, "This migration permanently replaces Ice with Thaw."
  end
end
