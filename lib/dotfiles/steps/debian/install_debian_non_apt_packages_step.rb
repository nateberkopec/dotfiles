require "json"
require "securerandom"

class Dotfiles::Step::InstallDebianNonAptPackagesStep < Dotfiles::Step
  debian_only

  GHOSTTY_APPIMAGE_REPO = "pkgforge-dev/ghostty-appimage".freeze
  GHOSTTY_APPIMAGE_ARCH = {
    "x86_64" => "x86_64",
    "aarch64" => "aarch64",
    "arm64" => "aarch64"
  }.freeze
  CLAUDE_CODE_INSTALL_URL = "https://claude.ai/install.sh".freeze

  def self.display_name
    "Debian Non-Apt Packages"
  end

  def self.depends_on
    [Dotfiles::Step::InstallDebianPackagesStep]
  end

  def should_run?
    missing_packages.any?
  end

  def run
    install_cargo_packages
    install_claude_code if configured_packages.include?("claude-code")
    install_ghostty if configured_packages.include?("ghostty")
    install_yq if configured_packages.include?("yq")
    @configured_packages = @missing_packages = nil
  end

  def complete?
    super
    missing_packages.each { |pkg| add_error("Non-APT package not installed: #{pkg}") }
    missing_packages.empty?
  end

  private

  def configured_packages
    @configured_packages ||= @config.debian_non_apt_packages
  end

  def missing_packages
    @missing_packages ||= configured_packages.reject { |pkg| package_installed?(pkg) }
  end

  def package_installed?(pkg)
    command = {
      "claude-code" => "claude",
      "difftastic" => "difft"
    }.fetch(pkg, pkg)
    bin_paths = [File.join(@home, ".local", "bin", command), File.join(@home, ".cargo", "bin", command)]
    command_exists?(command) || bin_paths.any? { |path| @system.file_exist?(path) }
  end

  def install_cargo_packages
    packages = configured_packages.select { |pkg| cargo_packages.key?(pkg) && !package_installed?(pkg) }
    return if packages.empty?
    cargo = cargo_command
    unless cargo
      add_error("cargo not available; cannot install #{packages.join(", ")}")
      return
    end
    packages.each { |pkg| install_cargo_package(cargo, pkg) }
  end

  def install_cargo_package(cargo, pkg)
    crate = cargo_packages.fetch(pkg)
    output, status = execute("#{cargo} install --locked --root #{File.join(@home, ".local")} #{crate}")
    add_error("cargo install #{crate} failed (status #{status}): #{output}") unless status == 0
  end

  def cargo_command
    cargo_path = File.join(@home, ".cargo", "bin", "cargo")
    return cargo_path if @system.file_exist?(cargo_path)
    return cargo_path if install_rustup
    return "cargo" if command_exists?("cargo")
    nil
  end

  def install_rustup
    tmp = temp_path("rustup")
    output, status = execute("curl -fsSL https://sh.rustup.rs -o #{tmp}")
    if status != 0
      add_error("rustup download failed (status #{status}): #{output}")
      @system.rm_rf(tmp)
      return false
    end
    output, status = execute("sh #{tmp} -y --profile minimal --no-modify-path")
    @system.rm_rf(tmp)
    add_error("rustup install failed (status #{status}): #{output}") unless status == 0
    status == 0
  end

  def install_yq
    install_direct_download(
      name: "yq",
      url: yq_download_url,
      error_prefix: "yq",
      error_message: "yq download not configured for architecture: #{system_arch}"
    )
  end

  def install_claude_code
    return if package_installed?("claude-code")
    output, status = execute("curl -fsSL #{CLAUDE_CODE_INSTALL_URL} | bash")
    add_error("Claude Code install failed (status #{status}): #{output}") unless status == 0
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

  def system_arch
    @system_arch ||= begin
      output, status = @system.execute("uname -m")
      if status == 0
        output.strip
      else
        ""
      end
    end
  end

  def temp_path(label)
    File.join("/tmp", "dotfiles-#{label}-#{SecureRandom.hex(6)}")
  end

  def install_direct_download(name:, url:, error_prefix:, error_message:)
    return if package_installed?(name)
    unless url
      add_error(error_message)
      return
    end
    dest = File.join(@home, ".local", "bin", name)
    download_and_install(url, dest, label: name, error_prefix: error_prefix)
  end

  def cargo_packages
    @cargo_packages ||= begin
      raw = @config.fetch("debian_non_apt_cargo_packages", [])
      case raw
      when Hash
        raw.transform_keys(&:to_s)
      when Array
        raw.map { |item| [item.to_s, item.to_s] }.to_h
      else
        {}
      end
    end
  end

  def yq_download_url
    config = @config.fetch("debian_non_apt_yq", {})
    base = config.fetch("url", nil)
    return nil unless base
    assets = config.fetch("assets", {}).transform_keys(&:to_s)
    asset = assets[system_arch]
    return nil unless asset
    "#{base}/#{asset}"
  end

  def download_and_install(url, dest, label:, error_prefix:)
    tmp = temp_path(label)
    output, status = execute("curl -fsSL #{url} -o #{tmp}")
    if status != 0
      add_error("#{error_prefix} download failed (status #{status}): #{output}")
      @system.rm_rf(tmp)
      return false
    end
    @system.mkdir_p(File.dirname(dest))
    output, status = execute("install -m 755 #{tmp} #{dest}")
    @system.rm_rf(tmp)
    add_error("#{error_prefix} install failed (status #{status}): #{output}") unless status == 0
    status == 0
  end
end
