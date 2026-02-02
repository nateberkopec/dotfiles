require "json"

class Dotfiles::Step::InstallDebianGhosttyStep < Dotfiles::Step
  include Dotfiles::Step::DebianNonAptHelper

  debian_only

  GHOSTTY_APPIMAGE_REPO = "pkgforge-dev/ghostty-appimage".freeze
  GHOSTTY_APPIMAGE_ARCH = {
    "x86_64" => "x86_64",
    "aarch64" => "aarch64",
    "arm64" => "aarch64"
  }.freeze

  def self.display_name
    "Ghostty"
  end

  def self.depends_on
    [Dotfiles::Step::InstallDebianPackagesStep]
  end

  def should_run?
    configured? && !package_installed?("ghostty")
  end

  def run
    install_ghostty if configured?
  end

  def complete?
    super
    return true unless configured?
    return true if package_installed?("ghostty")
    add_error("Non-APT package not installed: ghostty")
    false
  end

  private

  def configured?
    @config.debian_non_apt_packages.include?("ghostty")
  end

  def install_ghostty
    install_direct_download(
      name: "ghostty",
      url: ghostty_appimage_url,
      error_prefix: "Ghostty",
      error_message: "Ghostty AppImage not available for architecture: #{system_arch}"
    )
  end

  def ghostty_appimage_url
    arch = GHOSTTY_APPIMAGE_ARCH[system_arch]
    return nil unless arch
    release = ghostty_release
    return nil unless release
    assets = release.fetch("assets", [])
    asset = assets.find { |item| item.fetch("name", "").end_with?("#{arch}.AppImage") }
    asset&.fetch("browser_download_url", nil)
  end

  def ghostty_release
    output, status = execute("curl -fsSL https://api.github.com/repos/#{GHOSTTY_APPIMAGE_REPO}/releases")
    return nil unless status == 0
    releases = JSON.parse(output)
    releases.find { |release| !release["prerelease"] } || releases.first
  rescue JSON::ParserError => e
    add_error("Ghostty release metadata parse failed: #{e.message}")
    nil
  end
end
