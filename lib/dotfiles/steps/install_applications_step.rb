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
    @config.packages["applications"].all? do |app|
      @system.dir_exist?(app["path"])
    end
  rescue
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
