class Dotfiles::Step::InstallDebianDroidStep < Dotfiles::Step
  DESCRIPTION = "Installs Factory Droid on Debian/Ubuntu when configured as a non-APT package.".freeze
  DROID_INSTALL_URL = "https://app.factory.ai/cli".freeze

  debian_only

  def self.display_name
    "Factory Droid"
  end

  def should_run?
    allowed_on_platform? && configured? && !installed?
  end

  def run
    install if configured?
  end

  def complete?
    super
    return true unless configured?
    return true if installed?

    add_error("Non-APT package not installed: droid")
    false
  end

  private

  def configured?
    @config.debian_non_apt_packages.include?("droid")
  end

  def installed?
    command_exists?("droid") || droid_bin_paths.any? { |path| @system.file_exist?(path) }
  end

  def droid_bin_paths
    [
      File.join(@home, ".local", "bin", "droid"),
      File.join(@home, ".cargo", "bin", "droid")
    ]
  end

  def install
    return if installed?

    output, status = execute(shell_script('curl -fsSL "$1" | "$2"', DROID_INSTALL_URL, "sh"))
    add_error("Droid install failed (status #{status}): #{output}") unless status == 0
  end
end
