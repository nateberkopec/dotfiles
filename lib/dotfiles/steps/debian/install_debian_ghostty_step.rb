class Dotfiles::Step::InstallDebianGhosttyStep < Dotfiles::Step
  DESCRIPTION = "Installs a launcher wrapper for the mise-managed Ghostty AppImage on Debian/Ubuntu.".freeze
  GHOSTTY_TOOL = "github:pkgforge-dev/ghostty-appimage".freeze
  WRAPPER_MARKER = "dotfiles ghostty AppImage wrapper".freeze

  debian_only

  def self.display_name
    "Ghostty AppImage wrapper"
  end

  def self.depends_on
    [Dotfiles::Step::InstallMiseToolsStep]
  end

  def should_run?
    return false unless allowed_on_platform?

    appimage_path = ghostty_appimage_path
    !appimage_path.empty? && !wrapper_installed?(appimage_path)
  end

  def run
    appimage_path = ghostty_appimage_path
    return if appimage_path.empty? || wrapper_installed?(appimage_path)

    install_wrapper(appimage_path)
    reset_cache
  end

  def complete?
    super
    return true unless allowed_on_platform?

    appimage_path = ghostty_appimage_path
    return true if appimage_path.empty?
    return true if wrapper_installed?(appimage_path)

    add_error("Ghostty AppImage wrapper not installed")
    false
  end

  private

  def ghostty_appimage_path
    return @ghostty_appimage_path if defined?(@ghostty_appimage_path)
    return @ghostty_appimage_path = "" unless mise_available?

    install_dir, status = execute(command("mise", "--cd", @home, "where", GHOSTTY_TOOL))
    return @ghostty_appimage_path = "" unless status == 0

    path = File.join(install_dir.strip, "ghostty")
    @ghostty_appimage_path = @system.file_exist?(path) ? path : ""
  end

  def mise_available?
    command_exists?("mise")
  end

  def wrapper_installed?(appimage_path)
    output, status = execute(command("head", "-n", "2", appimage_path))
    status == 0 && output.include?(WRAPPER_MARKER)
  end

  def install_wrapper(appimage_path)
    backup_path = File.join(File.dirname(appimage_path), "ghostty.AppImage")
    @system.cp(appimage_path, backup_path)
    @system.write_file(appimage_path, ghostty_wrapper_script)
    @system.chmod(0o755, appimage_path)
  end

  def ghostty_wrapper_script
    <<~BASH
      #!/usr/bin/env bash
      # #{WRAPPER_MARKER}
      set -euo pipefail

      appimage_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
      exec "$appimage_dir/ghostty.AppImage" --appimage-extract-and-run "$@"
    BASH
  end

  def reset_cache
    @ghostty_appimage_path = nil
  end
end
