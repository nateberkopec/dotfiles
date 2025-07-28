class ConfigureApplicationsStep < Step
  def run
    debug 'Configuring application settings and preferences...'
    configure_ghostty
    configure_aerospace
    configure_git
    configure_vscode
  end

  def complete?
    ghostty_config = File.expand_path('~/Library/Application Support/com.mitchellh.ghostty/config')
    aerospace_config = File.expand_path('~/.aerospace.toml')
    git_config = File.expand_path('~/.gitconfig')
    vscode_settings = File.expand_path('~/Library/Application Support/Code/User/settings.json')
    vscode_keybindings = File.expand_path('~/Library/Application Support/Code/User/keybindings.json')

    File.exist?(ghostty_config) && File.exist?(aerospace_config) &&
    File.exist?(git_config) && File.exist?(vscode_settings) && File.exist?(vscode_keybindings)
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

  def configure_vscode
    debug 'Configuring VSCode...'
    vscode_dir = File.expand_path('~/Library/Application Support/Code/User')
    FileUtils.mkdir_p(vscode_dir)

    FileUtils.cp("#{@dotfiles_dir}/vscode/settings.json", vscode_dir)
    FileUtils.cp("#{@dotfiles_dir}/vscode/keybindings.json", vscode_dir)

    install_vscode_extensions
  end

  def install_vscode_extensions
    extensions_file = "#{@dotfiles_dir}/vscode/extensions.txt"
    return unless File.exist?(extensions_file)

    debug 'Installing VSCode extensions...'
    installed_extensions = execute('code --list-extensions', capture_output: true).split("\n")

    File.readlines(extensions_file).each do |extension|
      extension = extension.strip
      unless installed_extensions.include?(extension)
        debug "Installing VSCode extension: #{extension}"
        execute("code --install-extension #{extension}")
      else
        debug "VSCode extension already installed: #{extension}"
      end
    end
  end
end