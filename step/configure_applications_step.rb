class ConfigureApplicationsStep < Step
  def run
    debug 'Configuring application settings and preferences...'
    configure_ghostty
    configure_aerospace
    configure_git
  end

  def complete?
    ghostty_config = File.expand_path('~/Library/Application Support/com.mitchellh.ghostty/config')
    aerospace_config = File.expand_path('~/.aerospace.toml')
    git_config = File.expand_path('~/.gitconfig')

    File.exist?(ghostty_config) && File.exist?(aerospace_config) && File.exist?(git_config)
  end

  private

  def configure_ghostty
    debug 'Configuring Ghostty terminal...'
    ghostty_dir = File.expand_path('~/Library/Application Support/com.mitchellh.ghostty/')
    FileUtils.mkdir_p(ghostty_dir)
    FileUtils.cp("#{@dotfiles_dir}/ghostty/config", ghostty_dir)
  end

  def configure_aerospace
    debug 'Configuring Aerospace...'
    FileUtils.cp("#{@dotfiles_dir}/aerospace/.aerospace.toml",
                 File.expand_path('~'))
  end

  def configure_git
    debug 'Configuring Git global settings...'
    FileUtils.cp("#{@dotfiles_dir}/git/.gitconfig", File.expand_path('~/.gitconfig'))
  end

end