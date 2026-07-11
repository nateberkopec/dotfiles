class Dotfiles::Step::InstallDebianDesktopAppsStep < Dotfiles::Step
  DESCRIPTION = "Installs Debian desktop apps whose APT sources don't work in containers.".freeze

  debian_only

  def self.display_name
    "Debian Desktop Apps"
  end

  def should_run?
    missing_sources.any? || missing_packages.any?
  end

  def run
    desktop_apps.each { |app| ensure_source(app) }
    install_missing_packages
  end

  def complete?
    super
    missing_sources.each { |message| add_error(message) }
    missing_packages.each { |package| add_error("Desktop app not installed: #{package}") }
    @errors.empty?
  end

  private

  def desktop_apps
    return [] if skip_desktop_apps?

    @config.debian_desktop_apps
  end

  def ensure_source(app)
    [ensure_source_key(app), ensure_source_list(app)].any?
  end

  def ensure_source_key(app)
    key_url = app["key_url"]
    return false unless key_url

    keyring_path = source_keyring_path(app)
    return false if @system.file_exist?(keyring_path)

    tmp = temp_path("apt-key")
    output, status = execute(command("curl", "-fsSL", key_url, "-o", tmp))
    unless status == 0
      add_warning(title: "⚠️  Debian Source Key Download Failed", message: "Failed to download key from #{key_url}\n#{output}")
      @system.rm_rf(tmp)
      return false
    end

    output, status = execute(sudo_command("gpg", "--dearmor", "-o", keyring_path, tmp))
    @system.rm_rf(tmp)
    add_warning(title: "⚠️  Debian Source Key Install Failed", message: "Failed to install keyring at #{keyring_path}\n#{output}") unless status == 0
    status == 0
  end

  def ensure_source_list(app)
    list_path = source_list_path(app)
    expected = app["line"]
    return false if current_sources(list_path).include?(expected)

    tmp = temp_path("apt-source")
    @system.write_file(tmp, expected + "\n")
    output, status = execute(sudo_command("install", "-m", "644", tmp, list_path))
    @system.rm_rf(tmp)
    add_warning(title: "⚠️  Debian Source Install Failed", message: "Failed to install #{list_path}\n#{output}") unless status == 0
    status == 0
  end

  def install_missing_packages
    packages = missing_packages
    return if packages.empty?

    execute(sudo_command("env", "DEBIAN_FRONTEND=noninteractive", "apt-get", "update", "-y"))
    install_command = sudo_command("env", "DEBIAN_FRONTEND=noninteractive", "apt-get", "install", "-y", *packages)
    output, status = execute(install_command)
    add_error(format_command_error(install_command, status, output)) unless status == 0
  end

  def missing_sources
    desktop_apps.flat_map { |app| missing_source_entries(app) }
  end

  def missing_source_entries(app)
    list_path = source_list_path(app)
    entries = []
    entries << "APT source missing: #{list_path}" unless current_sources(list_path).include?(app["line"])
    entries << "APT keyring missing: #{source_keyring_path(app)}" unless @system.file_exist?(source_keyring_path(app))
    entries
  end

  def missing_packages
    desktop_apps.map { |app| app["package"] }.reject { |package| package_installed?(package) }
  end

  def package_installed?(package)
    command_succeeds?(command("dpkg", "-s", package))
  end

  def current_sources(list_path)
    return [] unless @system.file_exist?(list_path)

    @system.read_file(list_path).lines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
  end

  def source_list_path(app)
    "/etc/apt/sources.list.d/#{app.fetch("name")}.list"
  end

  def source_keyring_path(app)
    "/usr/share/keyrings/#{app.fetch("name")}-archive-keyring.gpg"
  end

  def skip_desktop_apps?
    (@system.respond_to?(:running_container?) && @system.running_container?) || ENV["GITHUB_ACTIONS"] == "true"
  end
end
