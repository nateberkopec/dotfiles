require "securerandom"

class Dotfiles::Step::InstallDebianPackagesStep < Dotfiles::Step
  debian_only

  def self.display_name
    "Debian Packages"
  end

  def should_run?
    missing_sources.any? || missing_packages.any?
  end

  def run
    sources_changed = ensure_sources
    update_apt if sources_changed || missing_packages.any?
    install_packages
    reset_cache
  end

  def complete?
    super
    if ci_or_noninteractive?
      report_unavailable_packages
      missing_installable.each { |pkg| add_warning(title: "⚠️  Debian package not installed", message: pkg) }
      missing_sources.each { |msg| add_warning(title: "⚠️  Debian source issue", message: msg) }
      return true
    end
    report_unavailable_packages
    missing_installable.each { |pkg| add_error("Debian package not installed: #{pkg}") }
    missing_sources.each { |msg| add_error(msg) }
    missing_installable.empty? && missing_sources.empty?
  end

  private

  def debian_sources
    @config.fetch("debian_sources", [])
  end

  def configured_packages
    @configured_packages ||= @config.packages.fetch("debian", {}).fetch("packages", []).uniq - non_apt_packages
  end

  def missing_packages
    @missing_packages ||= configured_packages.reject { |pkg| package_installed?(pkg) }
  end

  def non_apt_packages
    @non_apt_packages ||= @config.debian_non_apt_packages
  end

  def missing_installable
    missing_packages - unavailable_packages
  end

  def unavailable_packages
    @unavailable_packages ||= configured_packages - available_packages
  end

  def available_packages
    @available_packages ||= configured_packages.select { |pkg| package_available?(pkg) }
  end

  def package_installed?(pkg)
    _, status = @system.execute("dpkg -s #{pkg} >/dev/null 2>&1")
    status == 0
  end

  def package_available?(pkg)
    _, status = @system.execute("apt-cache show #{pkg} >/dev/null 2>&1")
    status == 0
  end

  def ensure_sources
    debian_sources.reduce(false) { |changed, source| ensure_source(source) || changed }
  end

  def ensure_source(source)
    changed = false
    changed |= ensure_source_key(source)
    changed |= ensure_source_list(source)
    changed
  end

  def ensure_source_key(source)
    key_url = source["key_url"]
    return false unless key_url

    keyring_path = source["signed_by"] || source_keyring_path(source)
    return false if @system.file_exist?(keyring_path)

    tmp = temp_path("apt-key")
    output, status = execute("curl -fsSL #{key_url} -o #{tmp}")
    unless status == 0
      add_warning(title: "⚠️  Debian Source Key Download Failed", message: "Failed to download key from #{key_url}\n#{output}")
      @system.rm_rf(tmp)
      return false
    end

    unless command_exists?("gpg")
      add_warning(title: "⚠️  Debian Source Key Skipped", message: "gpg not available; cannot install key for #{key_url}")
      @system.rm_rf(tmp)
      return false
    end

    output, status = execute("#{sudo_prefix}gpg --dearmor -o #{keyring_path} #{tmp}")
    @system.rm_rf(tmp)
    add_warning(title: "⚠️  Debian Source Key Install Failed", message: "Failed to install keyring at #{keyring_path}\n#{output}") unless status == 0
    status == 0
  end

  def ensure_source_list(source)
    list_path = source_list_path(source)
    expected = source_line(source)
    return false unless expected

    if @system.file_exist?(list_path)
      current = @system.read_file(list_path).strip
      return false if current == expected
    end

    tmp = temp_path("apt-source")
    @system.write_file(tmp, expected + "\n")
    output, status = execute("#{sudo_prefix}install -m 644 #{tmp} #{list_path}")
    @system.rm_rf(tmp)
    add_warning(title: "⚠️  Debian Source Install Failed", message: "Failed to install #{list_path}\n#{output}") unless status == 0
    status == 0
  end

  def source_line(source)
    return source["line"] if source["line"]
    repo = source["repo"]
    return nil unless repo

    suite = source.fetch("suite", "stable")
    components = Array(source.fetch("components", ["main"])).join(" ")
    signed_by = source["signed_by"] || (source["key_url"] ? source_keyring_path(source) : nil)
    options = signed_by ? " [signed-by=#{signed_by}]" : ""
    "deb#{options} #{repo} #{suite} #{components}"
  end

  def source_list_path(source)
    name = source.fetch("name", "dotfiles")
    "/etc/apt/sources.list.d/#{name}.list"
  end

  def source_keyring_path(source)
    name = source.fetch("name", "dotfiles")
    "/usr/share/keyrings/#{name}-archive-keyring.gpg"
  end

  def missing_sources
    debian_sources.flat_map { |source| missing_source_entries(source) }
  end

  def missing_source_entries(source)
    entries = []
    list_path = source_list_path(source)
    expected = source_line(source)
    if expected
      if !@system.file_exist?(list_path)
        entries << "APT source missing: #{list_path}"
      else
        current = @system.read_file(list_path).strip
        entries << "APT source mismatch: #{list_path}" unless current == expected
      end
    end

    key_url = source["key_url"]
    signed_by = source["signed_by"] || (key_url ? source_keyring_path(source) : nil)
    if signed_by && !@system.file_exist?(signed_by)
      entries << "APT keyring missing: #{signed_by}"
    end
    entries
  end

  def update_apt
    execute("#{sudo_prefix}DEBIAN_FRONTEND=noninteractive apt-get update -y")
  end

  def install_packages
    packages = missing_packages & available_packages
    return if packages.empty?

    output, status = execute("#{sudo_prefix}DEBIAN_FRONTEND=noninteractive apt-get install -y #{packages.join(" ")}")
    add_error("apt-get install failed (status #{status}): #{output}") unless status == 0
  end

  def report_unavailable_packages
    return if unavailable_packages.empty? || @reported_unavailable
    add_warning(
      title: "⚠️  Debian Packages Not Found",
      message: unavailable_packages.map { |pkg| "• #{pkg}" }.join("\n")
    )
    @reported_unavailable = true
  end

  def sudo_prefix
    return "" if root?
    "sudo "
  end

  def root?
    output, status = @system.execute("id -u")
    status == 0 && output.strip == "0"
  end

  def temp_path(label)
    File.join("/tmp", "dotfiles-#{label}-#{SecureRandom.hex(6)}")
  end

  def reset_cache
    @configured_packages = nil
    @missing_packages = nil
    @available_packages = nil
    @unavailable_packages = nil
  end

  def ci_or_noninteractive?
    ENV["CI"] || ENV["NONINTERACTIVE"]
  end
end
