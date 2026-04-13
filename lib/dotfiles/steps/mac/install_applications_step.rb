class Dotfiles::Step::InstallApplicationsStep < Dotfiles::Step
  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallHomebrewStep]
  end

  def initialize(**kwargs)
    super
    @skipped_apps = []
  end

  def run
    debug "Installing applications..."
    @config.applications.each do |app|
      install_application(app)
    end
  end

  def complete?
    super
    missing_apps = @config.applications.reject { |app| app_installed?(app) || skipped_app?(app) }
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
    output, status = @system.execute("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew install --cask #{appdir_flag} #{app["brew_cask"]} 2>&1")
    return if status == 0

    debug "Failed to install #{app["name"]}: #{output}" if @debug
    skip_app_without_admin(app, output) if non_admin_cask_install?
  end

  def install_cli_tap(app)
    brew_quiet("install #{app["cli_tap"]}")
  end

  def skipped_app?(app)
    @skipped_apps.include?(app["name"])
  end

  def non_admin_cask_install?
    !user_has_admin_rights?
  end

  def skip_app_without_admin(app, output)
    return if skipped_app?(app)

    @skipped_apps << app["name"]
    add_warning(
      title: "⚠️  Application Installation Skipped",
      message: "No admin rights detected. Could not install #{app["name"]}.\n#{output.to_s.lines.first.to_s.strip}"
    )
  end
end
