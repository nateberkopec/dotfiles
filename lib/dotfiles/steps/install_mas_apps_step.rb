class Dotfiles::Step::InstallMasAppsStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def run
    debug "Installing Mac App Store apps..."
    mas_apps.each do |app_id, app_name|
      install_mas_app(app_id, app_name)
    end
  end

  def should_run?
    if ENV["CI"]
      debug "Skipping Mac App Store installation in CI environment"
      return false
    end

    check_outdated_apps
    !complete?
  end

  def complete?
    return true if ENV["CI"]

    mas_apps.all? { |app_id, _| app_installed?(app_id) }
  rescue
    false
  end

  private

  def install_mas_app(app_id, app_name)
    if app_installed?(app_id)
      debug "#{app_name} is already installed, skipping..."
    else
      debug "Installing #{app_name}..."
      @system.execute("mas install #{app_id}")
    end
  end

  def app_installed?(app_id)
    installed_apps[app_id.to_s]
  end

  def installed_apps
    @installed_apps ||= mas_apps.each_with_object({}) do |(app_id, _), acc|
      _, status = @system.execute("mas list | grep '^#{app_id}'")
      acc[app_id.to_s] = status == 0
    end
  end

  def mas_apps
    @config.mas_apps.fetch("mas_apps", {})
  end

  def check_outdated_apps
    output, = @system.execute("mas outdated")
    return if output.strip.empty?

    outdated_list = output.strip.split("\n").map { |line| "• #{line}" }.join("\n")
    add_notice(
      title: "📦 Mac App Store Updates Available",
      message: "The following apps have updates available:\n\n#{outdated_list}\n\nRun 'mas upgrade' to update them."
    )
  end
end
