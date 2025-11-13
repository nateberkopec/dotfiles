class Dotfiles::Step::VSCodeConfigurationStep < Dotfiles::Step
  def self.display_name
    "VS Code Configuration"
  end

  def self.depends_on
    [Dotfiles::Step::InstallApplicationsStep]
  end

  def run
    install_vscode_extensions unless ci_or_noninteractive?
  end

  def complete?
    super
    unless ci_or_noninteractive?
      add_error("VSCode extensions not fully installed") unless extensions_installed?
    end
    @errors.empty?
  end

  def should_run?
    return false if ci_or_noninteractive?
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

  def extensions_installed?
    extensions_file = File.join(@home, "Library", "Application Support", "Code", "User", "extensions.txt")
    return true unless @system.file_exist?(extensions_file)
    return true unless command_exists?("code")

    installed_extensions, = execute("code --list-extensions")
    installed_extensions = installed_extensions.split("\n")

    expected_extensions = @system.readlines(extensions_file).map(&:strip)
    expected_extensions.all? { |ext| installed_extensions.include?(ext) }
  end

  def install_vscode_extensions
    extensions_file = File.join(@home, "Library", "Application Support", "Code", "User", "extensions.txt")
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
