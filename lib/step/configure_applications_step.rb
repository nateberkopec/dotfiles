class ConfigureApplicationsStep < Step
  def run
    debug 'Configuring application settings and preferences...'
    configure_ghostty
    configure_aerospace
    configure_git
  end

  def complete?
    ghostty_config = @config.expand_path('ghostty_config_file', 'application_paths')
    aerospace_config = @config.expand_path('aerospace_config')
    git_config = @config.expand_path('gitconfig')

    File.exist?(ghostty_config) && File.exist?(aerospace_config) && File.exist?(git_config)
  end

  private

  def configure_ghostty
    debug 'Configuring Ghostty terminal...'
    ghostty_dir = @config.expand_path('ghostty_config_dir', 'application_paths')
    FileUtils.mkdir_p(ghostty_dir)
    FileUtils.cp(@config.source_path('ghostty_config'), ghostty_dir)
  end

  def configure_aerospace
    debug 'Configuring Aerospace...'
    FileUtils.cp(@config.source_path('aerospace_config'), @config.expand_path('aerospace_config'))
  end

  def configure_git
    debug 'Configuring Git global settings...'
    FileUtils.cp(@config.source_path('git_config'), @config.expand_path('gitconfig'))
  end

end