class Dotfiles::Step::ConfigureApplicationsStep < Dotfiles::Step
  def run
    debug "Configuring application settings and preferences..."
    configure_ghostty
    configure_aerospace
    configure_git
  end

  def complete?
    ghostty_config = app_path("ghostty_config_file")
    aerospace_config = home_path("aerospace_config")
    git_config = home_path("gitconfig")

    File.exist?(ghostty_config) && File.exist?(aerospace_config) && File.exist?(git_config)
  end

  def update
    copy_if_exists(app_path("ghostty_config_file"), dotfiles_source("ghostty_config"))
    copy_if_exists(home_path("aerospace_config"), dotfiles_source("aerospace_config"))
    copy_if_exists(home_path("gitconfig"), dotfiles_source("git_config"))
  end

  private

  def configure_ghostty
    debug "Configuring Ghostty terminal..."
    ghostty_dir = app_path("ghostty_config_dir")
    FileUtils.mkdir_p(ghostty_dir)
    FileUtils.cp(dotfiles_source("ghostty_config"), ghostty_dir)
  end

  def configure_aerospace
    debug "Configuring Aerospace..."
    FileUtils.cp(dotfiles_source("aerospace_config"), home_path("aerospace_config"))
  end

  def configure_git
    debug "Configuring Git global settings..."
    FileUtils.cp(dotfiles_source("git_config"), home_path("gitconfig"))
  end
end
