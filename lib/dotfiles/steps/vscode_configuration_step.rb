class Dotfiles::Step::VSCodeConfigurationStep < Dotfiles::Step
  def self.display_name
    "VS Code Configuration"
  end

  def self.depends_on
    [Dotfiles::Step::InstallApplicationsStep]
  end

  def run
    debug "Configuring VSCode..."
    vscode_dir = app_path("vscode_user_dir")
    @system.mkdir_p(vscode_dir)

    @system.cp(dotfiles_source("vscode_settings"), vscode_dir)
    @system.cp(dotfiles_source("vscode_keybindings"), vscode_dir)

    install_vscode_extensions unless ci_or_noninteractive?
  end

  def complete?
    vscode_settings = app_path("vscode_settings")
    vscode_keybindings = app_path("vscode_keybindings")

    @system.file_exist?(vscode_settings) && @system.file_exist?(vscode_keybindings)
  end

  def update
    copy_if_exists(app_path("vscode_settings"), dotfiles_source("vscode_settings"))
    copy_if_exists(app_path("vscode_keybindings"), dotfiles_source("vscode_keybindings"))

    extensions_dest = dotfiles_source("vscode_extensions")
    if extensions_dest && command_exists?("code")
      stdout, = execute("code --list-extensions")
      @system.mkdir_p(File.dirname(extensions_dest))
      @system.write_file(extensions_dest, stdout + "\n")
    end
  end

  private

  def install_vscode_extensions
    extensions_file = dotfiles_source("vscode_extensions")
    return unless @system.file_exist?(extensions_file)

    debug "Installing VSCode extensions..."
    installed_extensions, = execute("code --list-extensions")
    installed_extensions = installed_extensions.split("\n")

    @system.readlines(extensions_file).each do |extension|
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
