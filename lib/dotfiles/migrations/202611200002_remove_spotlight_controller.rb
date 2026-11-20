class Dotfiles::Migration::RemoveSpotlightController < Dotfiles::Migration
  VERSION = 202611200002
  DAEMON = "/Library/LaunchDaemons/com.user.spotlight-controller.plist".freeze
  CONTROLLER = "/usr/local/libexec/dotfiles-spotlight-controller".freeze

  macos_only

  def up
    remove_controller if [DAEMON, CONTROLLER].any? { |path| @system.file_exist?(path) }
    @system.rm_rf(File.join(@home, ".local", "share", "spotlight"))
  end

  def down
    raise NotImplementedError, "This migration removes the retired Spotlight controller and cannot be safely reversed."
  end

  private

  def remove_controller
    execute(shell_script(<<~SH))
      sudo launchctl bootout system #{DAEMON} 2>/dev/null || true
      sudo rm -rf #{DAEMON} #{CONTROLLER} /var/db/dotfiles-spotlight /var/log/dotfiles-spotlight.log
      sudo mdutil -i on / /System/Volumes/Data
    SH
  end
end
