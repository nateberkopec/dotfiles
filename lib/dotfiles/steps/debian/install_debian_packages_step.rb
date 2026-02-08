class Dotfiles::Step::InstallDebianPackagesStep < Dotfiles::Step
  include Dotfiles::Step::DebianPackages

  debian_only

  def self.display_name
    "Debian Packages"
  end

  def should_run?
    missing_sources.any? || missing_packages.any?
  end

  def run
    sources_changed = ensure_sources
    if sources_changed || missing_packages.any?
      output, status = update_apt
      record_update_failure(output, status) if status != 0
    end
    install_packages
    reset_cache
  end

  def complete?
    super
    report_unavailable_packages
    report_apt_failures
    return true if noninteractive_complete?

    report_missing_install_errors
    missing_installable.empty? && missing_sources.empty?
  end

  private

  def debian_sources
    @config.fetch("debian_sources", [])
  end

  def noninteractive_complete?
    return false unless noninteractive_mode?

    if ENV["CI"] == "true"
      report_missing_install_errors
      missing_installable.empty? && missing_sources.empty?
    else
      report_missing_install_warnings
      true
    end
  end

  def noninteractive_mode?
    ENV["CI"] || ENV["NONINTERACTIVE"]
  end

  def report_missing_install_warnings
    add_missing_installable_warning if missing_installable.any?
    missing_sources.each { |msg| add_warning(title: "⚠️  Debian source issue", message: msg) }
  end

  def add_missing_installable_warning
    add_warning(
      title: "⚠️  Debian packages not installed",
      message: missing_installable.map { |pkg| "• #{pkg}" }.join("\n")
    )
  end

  def report_missing_install_errors
    missing_installable.each { |pkg| add_error("Debian package not installed: #{pkg}") }
    missing_sources.each { |msg| add_error(msg) }
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

  def ensure_sources
    debian_sources.map { |source| ensure_source(source) }.any?
  end

  def ensure_source(source)
    [ensure_source_key(source), ensure_source_list(source)].any?
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
    signed_by = source_keyring_for(source)
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
    list_path = source_list_path(source)
    expected = source_line(source)
    missing_source_list_entries(list_path, expected) + missing_source_key_entries(source)
  end

  def missing_source_list_entries(list_path, expected)
    return [] unless expected
    return ["APT source missing: #{list_path}"] unless @system.file_exist?(list_path)
    return [] if current_sources(list_path).include?(expected)
    ["APT source mismatch: #{list_path}"]
  end

  def current_sources(list_path)
    @system.read_file(list_path).lines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
  end

  def missing_source_key_entries(source)
    signed_by = source_keyring_for(source)
    return [] unless signed_by
    return [] if @system.file_exist?(signed_by)
    ["APT keyring missing: #{signed_by}"]
  end

  def source_keyring_for(source)
    key_url = source["key_url"]
    source["signed_by"] || (key_url ? source_keyring_path(source) : nil)
  end

  def install_packages
    packages = missing_packages & available_packages
    return if packages.empty?

    output, status = run_apt("apt-get install -y #{packages.join(" ")}")
    return if status == 0

    @install_failed_status = status
    @install_failed_output = output
  end

  def report_unavailable_packages
    return if unavailable_packages.empty? || @reported_unavailable
    add_warning(
      title: "⚠️  Debian Packages Not Found",
      message: unavailable_packages.map { |pkg| "• #{pkg}" }.join("\n")
    )
    @reported_unavailable = true
  end

  def package_installed?(pkg)
    return docker_installed? if pkg == "docker.io"
    super
  end

  def docker_installed?
    return true if command_exists?("docker")
    %w[docker-ce docker-ce-cli containerd.io].any? do |name|
      command_succeeds?("dpkg -s #{name} >/dev/null 2>&1")
    end
  end

  def record_update_failure(output, status)
    @update_failed_status = status
    @update_failed_output = output
  end

  def report_apt_failures
    if @update_failed_status
      add_error("apt-get update failed (status #{@update_failed_status}): #{@update_failed_output}")
    end
    if @install_failed_status
      add_error("apt-get install failed (status #{@install_failed_status}): #{@install_failed_output}")
    end
  end

  def reset_cache
    @configured_packages = nil
    @missing_packages = nil
    @available_packages = nil
    @unavailable_packages = nil
  end
end
