class Dotfiles::Step::InstallApplicationsStep < Dotfiles::Step
  DESCRIPTION = "Installs configured macOS applications.".freeze

  macos_only

  def self.depends_on
    [Dotfiles::Step::UpdateHomebrewStep]
  end

  def run
    debug "Installing applications..."
    @config.applications.each do |app|
      install_application(app)
    end
  end

  def complete?
    super
    missing_apps = @config.applications.reject { |app| app_installed?(app) }
    missing_apps.each { |app| add_error("#{app["name"]} not installed at #{expected_install_locations(app).join(" or ")}") }
    missing_apps.empty?
  rescue => e
    add_error("Failed to check application installation status: #{e.message}")
    false
  end

  private

  def install_application(app)
    return debug("#{app["name"]} is already installed, skipping...") if app_installed?(app)
    install_app_cask(app)
    install_cli_tap(app) if app["cli_tap"]
  end

  def app_installed?(app)
    expected_install_locations(app).any? { |path| @system.dir_exist?(path) }
  end

  def expected_install_locations(app)
    path = app["path"]
    return [path] if user_has_admin_rights?
    return [path] unless path.start_with?("/Applications/")

    [path, File.join(@home, "Applications", File.basename(path))]
  end

  def install_app_cask(app)
    debug "Installing #{app["name"]}..."
    appdir_flag = user_has_admin_rights? ? "" : "--appdir=~/Applications"
    brew_quiet("install --cask #{appdir_flag} #{app["brew_cask"]}")
  end

  def install_cli_tap(app)
    brew_quiet("install #{app["cli_tap"]}")
  end
end
