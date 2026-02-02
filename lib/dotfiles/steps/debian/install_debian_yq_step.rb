class Dotfiles::Step::InstallDebianYqStep < Dotfiles::Step
  include Dotfiles::Step::DebianNonAptHelper

  debian_only

  def self.display_name
    "yq"
  end

  def self.depends_on
    [Dotfiles::Step::InstallDebianPackagesStep]
  end

  def should_run?
    configured? && !package_installed?("yq")
  end

  def run
    install_yq if configured?
  end

  def complete?
    super
    return true unless configured?
    return true if package_installed?("yq")
    add_error("Non-APT package not installed: yq")
    false
  end

  private

  def configured?
    @config.debian_non_apt_packages.include?("yq")
  end

  def install_yq
    install_direct_download(
      name: "yq",
      url: yq_download_url,
      error_prefix: "yq",
      error_message: "yq download not configured for architecture: #{system_arch}"
    )
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
end
