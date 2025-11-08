class Dotfiles::Step::InstallApplicationsStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::InstallHomebrewStep]
  end

  def run
    debug "Installing applications..."
    @config.packages["applications"].each do |app|
      install_application(app)
    end
  end

  def complete?
    super
    missing_apps = @config.packages["applications"].reject { |app| @system.dir_exist?(app["path"]) }
    missing_apps.each { |app| add_error("#{app["name"]} not installed at #{app["path"]}") }
    missing_apps.empty?
  rescue => e
    add_error("Failed to check application installation status: #{e.message}")
    false
  end

  private

  def install_application(app)
    if @system.dir_exist?(app["path"])
      debug "#{app["name"]} is already installed, skipping..."
    else
      debug "Installing #{app["name"]}..."

      appdir_flag = user_has_admin_rights? ? "" : "--appdir=~/Applications"

      if app["cli_tap"]
        brew_quiet("install --cask #{appdir_flag} #{app["brew_cask"]} #{app["cli_tap"]}")
      else
        brew_quiet("install --cask #{appdir_flag} #{app["brew_cask"]}")
      end
    end
  end
end
