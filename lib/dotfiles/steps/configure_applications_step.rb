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

    files_match?(ghostty_config, dotfiles_source("ghostty_config")) &&
      files_match?(aerospace_config, dotfiles_source("aerospace_config")) &&
      files_match?(git_config, dotfiles_source("git_config"))
  end

  def update
    copy_if_changed(app_path("ghostty_config_file"), dotfiles_source("ghostty_config"))
    copy_if_changed(home_path("aerospace_config"), dotfiles_source("aerospace_config"))
    copy_if_changed(home_path("gitconfig"), dotfiles_source("git_config"))
  end

  private

  def configure_ghostty
    debug "Configuring Ghostty terminal..."
    ghostty_dir = app_path("ghostty_config_dir")
    @system.mkdir_p(ghostty_dir)
    @system.cp(dotfiles_source("ghostty_config"), ghostty_dir)
  end

  def configure_aerospace
    debug "Configuring Aerospace..."
    @system.cp(dotfiles_source("aerospace_config"), home_path("aerospace_config"))
  end

  def configure_git
    debug "Configuring Git global settings..."
    @system.cp(dotfiles_source("git_config"), home_path("gitconfig"))
  end
end
