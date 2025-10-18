class VSCodeConfigurationStep < Step
  def self.display_name
    "VS Code Configuration"
  end

  def self.depends_on
    [InstallApplicationsStep, CloneDotfilesStep]
  end

  def run
    debug "Configuring VSCode..."
    vscode_dir = @config.expand_path("vscode_user_dir", "application_paths")
    FileUtils.mkdir_p(vscode_dir)

    FileUtils.cp(@config.source_path("vscode_settings"), vscode_dir)
    FileUtils.cp(@config.source_path("vscode_keybindings"), vscode_dir)

    install_vscode_extensions
  end

  def complete?
    return true if ci_or_noninteractive?

    vscode_settings = @config.expand_path("vscode_settings", "application_paths")
    vscode_keybindings = @config.expand_path("vscode_keybindings", "application_paths")

    File.exist?(vscode_settings) && File.exist?(vscode_keybindings)
  end

  # Sync VSCode user settings and extensions list back into dotfiles
  def update
    settings_src = @config.expand_path("vscode_settings", "application_paths")
    keybindings_src = @config.expand_path("vscode_keybindings", "application_paths")

    settings_dest = @config.source_path("vscode_settings")
    keybindings_dest = @config.source_path("vscode_keybindings")
    extensions_dest = @config.source_path("vscode_extensions")

    if settings_src && settings_dest && File.exist?(settings_src)
      FileUtils.mkdir_p(File.dirname(settings_dest))
      FileUtils.cp(settings_src, settings_dest)
    end

    if keybindings_src && keybindings_dest && File.exist?(keybindings_src)
      FileUtils.mkdir_p(File.dirname(keybindings_dest))
      FileUtils.cp(keybindings_src, keybindings_dest)
    end

    # Export installed extensions if VSCode CLI is present
    if extensions_dest && command_exists?("code")
      stdout = execute("code --list-extensions", capture_output: true)
      FileUtils.mkdir_p(File.dirname(extensions_dest))
      File.write(extensions_dest, stdout.strip + "\n")
    end
  end

  private

  def install_vscode_extensions
    extensions_file = @config.source_path("vscode_extensions")
    return unless File.exist?(extensions_file)

    debug "Installing VSCode extensions..."
    installed_extensions = execute("code --list-extensions", capture_output: true).split("\n")

    File.readlines(extensions_file).each do |extension|
      extension = extension.strip
      if installed_extensions.include?(extension)
        debug "VSCode extension already installed: #{extension}"
      else
        debug "Installing VSCode extension: #{extension}"
        execute("code --install-extension #{extension}")
      end
    end
  end
end
