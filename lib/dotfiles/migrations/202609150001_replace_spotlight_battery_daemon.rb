class Dotfiles::Migration::ReplaceSpotlightBatteryDaemon < Dotfiles::Migration
  VERSION = 202609150001

  macos_only

  def up
    execute(shell_script(<<~SH))
      sudo launchctl bootout system /Library/LaunchDaemons/com.user.spotlight-battery.plist 2>/dev/null || true
      sudo launchctl bootout system /Library/LaunchDaemons/local.spotlight-resume.plist 2>/dev/null || true
      sudo rm -f /Library/LaunchDaemons/com.user.spotlight-battery.plist /Library/LaunchDaemons/local.spotlight-resume.plist
    SH
    @system.rm_rf(File.join(@home, ".local", "share", "spotlight"))
  end

  def down
    raise NotImplementedError, "This migration removes obsolete Spotlight daemons and cannot be safely reversed."
  end
end
