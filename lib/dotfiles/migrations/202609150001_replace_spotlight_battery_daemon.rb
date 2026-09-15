class Dotfiles::Migration::ReplaceSpotlightBatteryDaemon < Dotfiles::Migration
  VERSION = 202609150001

  macos_only

  def up
    remove_legacy_daemon if @system.file_exist?(legacy_daemon_path)
    @system.rm_rf(File.join(@home, ".local", "share", "spotlight"))
  end

  def down
    raise NotImplementedError, "This migration removes the obsolete Spotlight battery daemon and cannot be safely reversed."
  end

  private

  def remove_legacy_daemon
    execute(shell_script(<<~SH))
      sudo launchctl bootout system #{legacy_daemon_path} 2>/dev/null || true
      sudo rm -f #{legacy_daemon_path}
    SH
  end

  def legacy_daemon_path
    "/Library/LaunchDaemons/com.user.spotlight-battery.plist"
  end
end
