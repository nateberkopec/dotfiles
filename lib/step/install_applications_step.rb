class InstallApplicationsStep < Step
  def self.depends_on
    [InstallHomebrewStep]
  end
  def run
    debug 'Installing applications...'
    @config.packages['applications'].each do |app|
      install_application(app)
    end
  end

  def complete?
    @config.packages['applications'].all? do |app|
      Dir.exist?(app['path'])
    end
  rescue
    false
  end

  private

  def install_application(app)
    unless Dir.exist?(app['path'])
      debug "Installing #{app['name']}..."
      
      if app['cli_tap']
        brew_quiet("install --cask #{app['brew_cask']} #{app['cli_tap']}")
      else
        brew_quiet("install --cask #{app['brew_cask']}")
      end
    else
      debug "#{app['name']} is already installed, skipping..."
    end
  end
end