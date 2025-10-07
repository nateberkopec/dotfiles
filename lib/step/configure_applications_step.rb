class ConfigureApplicationsStep < Step
  def run
    debug "Configuring application settings and preferences..."
    configure_ghostty
    configure_aerospace
    configure_git
  end

  def complete?
    ghostty_config = @config.expand_path("ghostty_config_file", "application_paths")
    aerospace_config = @config.expand_path("aerospace_config")
    git_config = @config.expand_path("gitconfig")

    File.exist?(ghostty_config) && File.exist?(aerospace_config) && File.exist?(git_config)
  end

    def update
    # Ghostty
    ghostty_src = @config.expand_path("ghostty_config_file", "application_paths")
    ghostty_dest = @config.source_path("ghostty_config")
    if ghostty_src && ghostty_dest && File.exist?(ghostty_src)
      FileUtils.mkdir_p(File.dirname(ghostty_dest))
      FileUtils.cp(ghostty_src, ghostty_dest)
    end

    # Aerospace
    aerospace_src = @config.expand_path("aerospace_config")
    aerospace_dest = @config.source_path("aerospace_config")
    if aerospace_src && aerospace_dest && File.exist?(aerospace_src)
      FileUtils.mkdir_p(File.dirname(aerospace_dest))
      FileUtils.cp(aerospace_src, aerospace_dest)
    end

    # Git
    git_src = @config.expand_path("gitconfig")
    git_dest = @config.source_path("git_config")
    if git_src && git_dest && File.exist?(git_src)
      FileUtils.mkdir_p(File.dirname(git_dest))
      FileUtils.cp(git_src, git_dest)
    end
  end

  private

  def configure_ghostty
    debug "Configuring Ghostty terminal..."
    ghostty_dir = @config.expand_path("ghostty_config_dir", "application_paths")
    FileUtils.mkdir_p(ghostty_dir)
    FileUtils.cp(@config.source_path("ghostty_config"), ghostty_dir)
  end

  def configure_aerospace
    debug "Configuring Aerospace..."
    FileUtils.cp(@config.source_path("aerospace_config"), @config.expand_path("aerospace_config"))
  end

  def configure_git
    debug "Configuring Git global settings..."
    FileUtils.cp(@config.source_path("git_config"), @config.expand_path("gitconfig"))
  end
end
