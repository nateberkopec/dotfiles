class Dotfiles::Migration::AdoptOmniWM < Dotfiles::Migration
  VERSION = 202608200002
  LEGACY_CASKS = %w[aerospace omniwm].freeze
  LEGACY_TAPS = %w[nikitabobko/tap barutsrb/tap].freeze
  RETIRED_PATHS = [
    ".aerospace.toml",
    ".local/bin/omniwm-trial",
    ".local/state/omniwm-trial",
    "Library/Preferences/bobko.aerospace.plist"
  ].freeze

  macos_only

  def up
    stop_window_managers
    remove_login_items
    remove_homebrew_installs
    reset_aerospace_permissions
    @system.rm_rf(RETIRED_PATHS.map { |path| File.join(@home, path) })
    start_omniwm
  end

  def down
    raise NotImplementedError, "This migration permanently replaces AeroSpace with OmniWM."
  end

  private

  def stop_window_managers
    execute(shell_script("pkill -x AeroSpace 2>/dev/null || true; pkill -x OmniWM 2>/dev/null || true"))
  end

  def remove_login_items
    execute(command(
      "osascript",
      "-e", 'tell application "System Events"',
      "-e", 'if exists login item "AeroSpace" then delete login item "AeroSpace"',
      "-e", 'if exists login item "OmniWM" then delete login item "OmniWM"',
      "-e", "end tell"
    ))
  end

  def remove_homebrew_installs
    return unless command_exists?("brew")

    LEGACY_CASKS.each { |cask| uninstall_cask(cask) }
    LEGACY_TAPS.each { |tap| untap(tap) }
  end

  def uninstall_cask(cask)
    execute(homebrew_command("uninstall", "--cask", cask)) if command_succeeds?(homebrew_command("list", "--cask", cask))
  end

  def untap(tap)
    return unless command_succeeds?(tap_installed_command(tap))

    execute(homebrew_command("untap", tap))
  end

  def tap_installed_command(tap)
    shell_script(
      'env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew tap | grep -Fqx -- "$1"',
      tap
    )
  end

  def reset_aerospace_permissions
    execute(shell_script("tccutil reset Accessibility bobko.aerospace >/dev/null 2>&1 || true"))
  end

  def start_omniwm
    execute(shell_script('launchctl kickstart -k "gui/$(id -u)/dev.mise.omniwm"'))
  end
end
