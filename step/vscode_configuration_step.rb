class VSCodeConfigurationStep < Step
  def run
    debug 'Configuring VSCode...'
    vscode_dir = File.expand_path('~/Library/Application Support/Code/User')
    FileUtils.mkdir_p(vscode_dir)

    FileUtils.cp("#{@dotfiles_dir}/vscode/settings.json", vscode_dir)
    FileUtils.cp("#{@dotfiles_dir}/vscode/keybindings.json", vscode_dir)

    install_vscode_extensions
  end

  def complete?
    vscode_settings = File.expand_path('~/Library/Application Support/Code/User/settings.json')
    vscode_keybindings = File.expand_path('~/Library/Application Support/Code/User/keybindings.json')

    File.exist?(vscode_settings) && File.exist?(vscode_keybindings)
  end

  private

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