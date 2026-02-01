class Dotfiles::Step::VSCodeConfigurationStep < Dotfiles::Step
  prepend Dotfiles::Step::Sudoable

  macos_only

  def self.display_name
    "VS Code Configuration"
  end

  def self.depends_on
    [Dotfiles::Step::InstallApplicationsStep]
  end

  def run
    install_vscode_extensions
  end

  def complete?
    super
    add_error("VSCode extensions not fully installed") unless extensions_installed?
    @errors.empty?
  end

  def should_run?
    !extensions_installed?
  end

  def update
    extensions_file = File.join(@home, "Library", "Application Support", "Code", "User", "extensions.txt")
    if command_exists?("code")
      stdout, = execute("code --list-extensions")
      @system.mkdir_p(File.dirname(extensions_file))
      @system.write_file(extensions_file, stdout + "\n")
    end
  end

  private

  def extensions_file
    File.join(@home, "Library", "Application Support", "Code", "User", "extensions.txt")
  end

  def extensions_installed?
    return true unless @system.file_exist?(extensions_file) && command_exists?("code")
    expected_extensions.all? { |ext| installed_extensions.include?(ext) }
  end

  def installed_extensions
    execute("code --list-extensions").first.split("\n")
  end

  def expected_extensions
    @system.readlines(extensions_file).map(&:strip)
  end

  def install_vscode_extensions
    return unless @system.file_exist?(extensions_file)
    debug "Installing VSCode extensions..."
    installed = installed_extensions
    expected_extensions.each { |ext| install_extension_if_missing(ext, installed) }
  end

  def install_extension_if_missing(extension, installed)
    if installed.include?(extension)
      debug "VSCode extension already installed: #{extension}"
    else
      debug "Installing VSCode extension: #{extension}"
      execute("code --install-extension #{extension}")
    end
  end
end
