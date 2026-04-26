class Dotfiles::Step::InstallDebianGhosttyStep < Dotfiles::Step
  DESCRIPTION = "Installs the Ghostty AppImage and launcher on Debian/Ubuntu when configured.".freeze

  include Dotfiles::Step::DebianNonAptHelper

  CURL_RETRY_ARGS = "--retry 5 --retry-delay 2 --retry-max-time 120 --retry-all-errors".freeze
  GITHUB_API_HEADERS = [
    '-H "Accept: application/vnd.github+json"',
    '-H "X-GitHub-Api-Version: 2022-11-28"'
  ].freeze

  ARCH_MAP = {
    "x86_64" => "x86_64",
    "amd64" => "x86_64",
    "aarch64" => "aarch64",
    "arm64" => "aarch64"
  }.freeze
  RELEASE_API_URL = "https://api.github.com/repos/pkgforge-dev/ghostty-appimage/releases/latest".freeze

  debian_only

  def self.display_name
    "Ghostty"
  end

  def self.depends_on
    [Dotfiles::Step::InstallDebianPackagesStep]
  end

  def should_run?
    allowed_on_platform? && configured? && !installed?
  end

  def run
    install_ghostty unless !configured? || installed?
  end

  def complete?
    super
    return true unless configured?
    return true if installed?
    add_error("Non-APT package not installed: ghostty")
    false
  end

  private

  def configured?
    @config.debian_non_apt_packages.include?("ghostty")
  end

  def installed?
    package_installed?("ghostty")
  end

  def install_ghostty
    arch = ghostty_arch
    return if arch.empty?

    download_url = ghostty_download_url(arch)
    if download_url.empty?
      add_error("Could not resolve Ghostty AppImage download URL for #{arch}")
      return
    end

    appimage_tmp = download_appimage(download_url)
    return if appimage_tmp.empty?
    return unless install_appimage(appimage_tmp)

    install_wrapper
  end

  def ghostty_arch
    arch = ARCH_MAP[system_arch]
    return arch if arch

    add_error("Unsupported architecture for Ghostty AppImage: #{system_arch}")
    ""
  end

  def download_appimage(download_url)
    appimage_tmp = temp_path("ghostty-appimage")
    output, status = execute(curl_download_command(download_url, appimage_tmp))
    return appimage_tmp if status == 0

    add_error("Ghostty download failed (status #{status}): #{output}")
    @system.rm_rf(appimage_tmp)
    ""
  end

  def install_appimage(appimage_tmp)
    output, status = execute("#{sudo_prefix}install -d -m 755 /opt/ghostty && #{sudo_prefix}install -m 755 #{appimage_tmp} /opt/ghostty/ghostty.AppImage")
    @system.rm_rf(appimage_tmp)
    return true if status == 0

    add_error("Ghostty install failed (status #{status}): #{output}")
    false
  end

  def install_wrapper
    wrapper_tmp = temp_path("ghostty-wrapper")
    @system.write_file(wrapper_tmp, ghostty_wrapper_script)
    output, status = execute("#{sudo_prefix}install -m 755 #{wrapper_tmp} /usr/local/bin/ghostty")
    @system.rm_rf(wrapper_tmp)
    add_error("Ghostty launcher install failed (status #{status}): #{output}") unless status == 0
  end

  def ghostty_download_url(arch)
    metadata_path = temp_path("ghostty-release")
    _output, status = execute(github_release_metadata_command(metadata_path))
    return "" unless status == 0

    ruby = "ruby -rjson -e 'data=JSON.parse(File.read(ARGV[0])); arch=ARGV[1]; asset=data.fetch(\"assets\", []).find { |a| a[\"name\"] =~ /-#{arch}\\.AppImage$/ }; puts(asset ? asset[\"browser_download_url\"] : \"\")' #{metadata_path} #{arch}"
    url, _url_status = execute(ruby, quiet: true)
    @system.rm_rf(metadata_path)
    url.to_s.strip
  end

  def github_release_metadata_command(output_path)
    curl_download_command(RELEASE_API_URL, output_path, headers: github_api_headers)
  end

  def curl_download_command(url, output_path, headers: [])
    ["curl -fsSL", CURL_RETRY_ARGS, *headers, url, "-o", output_path].join(" ")
  end

  def github_api_headers
    GITHUB_API_HEADERS + github_authorization_header
  end

  def github_authorization_header
    token_env = github_token_env
    token_env ? [%(-H "Authorization: Bearer ${#{token_env}}")] : []
  end

  def github_token_env
    %w[GITHUB_TOKEN GH_TOKEN].find { |name| !ENV[name].to_s.empty? }
  end

  def ghostty_wrapper_script
    <<~BASH
      #!/usr/bin/env bash
      exec /opt/ghostty/ghostty.AppImage --appimage-extract-and-run "$@"
    BASH
  end
end
