class Dotfiles::Step::InstallDebianDesktopAppsStep < Dotfiles::Step
  DESCRIPTION = "Installs configured Debian desktop applications.".freeze
  debian_only

  def initialize(source_installer: nil, **kwargs)
    super(**kwargs)
    @source_installer = source_installer || Dotfiles::DebianDesktopSourceInstaller.new(system: @system)
  end

  def should_run?
    allowed_on_platform? && !skip? && missing_packages.any?
  end

  def run
    return if skip?
    @install_error = nil
    sources_installed = @config.debian_desktop_apps.all? { |app| @source_installer.install(app) }
    return @install_error = "Failed to install a Debian desktop application source" unless sources_installed
    return unless update_package_index

    packages = missing_packages
    return if packages.empty?
    install_command = sudo_command("env", "DEBIAN_FRONTEND=noninteractive", "apt-get", "install", "-y", *packages)
    output, status = execute(install_command)
    @install_error = format_command_error(install_command, status, output) unless status == 0
  end

  def complete?
    super
    return true if skip?
    add_error(@install_error) if @install_error
    missing_packages.each { |package| add_error("Debian desktop application not installed: #{package}") }
    errors.empty?
  end

  private

  def update_package_index
    update_command = sudo_command("apt-get", "update", "-y")
    output, status = execute(update_command)
    return true if status == 0

    @install_error = format_command_error(update_command, status, output)
    false
  end

  def missing_packages
    @config.debian_desktop_apps.map { |app| app["package"] }.reject { |package| command_succeeds?(command("dpkg", "-s", package)) }
  end

  def skip?
    ENV["CI"] || (@system.respond_to?(:running_container?) && @system.running_container?)
  end
end
