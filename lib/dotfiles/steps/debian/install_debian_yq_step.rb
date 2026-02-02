class Dotfiles::Step::InstallDebianYqStep < Dotfiles::Step
  include Dotfiles::Step::DebianNonAptStep

  def self.display_name
    "yq"
  end

  private

  def package_name
    "yq"
  end

  def install
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
