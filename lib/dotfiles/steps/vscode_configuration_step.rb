class Dotfiles::Step::VSCodeConfigurationStep < Dotfiles::Step
  prepend Dotfiles::Step::Sudoable

  def self.display_name
    "VS Code Configuration"
  end

  def self.depends_on
    Dotfiles::Step.system_packages_steps
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
    if command_exists?("code")
      stdout, = execute("code --list-extensions")
      @system.mkdir_p(File.dirname(extensions_file))
      @system.write_file(extensions_file, stdout + "\n")
    end
  end

  private

  def extensions_file
    if @system.macos?
      File.join(@home, "Library", "Application Support", "Code", "User", "extensions.txt")
    else
      File.join(config_home, "Code", "User", "extensions.txt")
    end
  end

  def extensions_installed?
    return true unless @system.file_exist?(extensions_file) && command_exists?("code")
    installed = installed_extensions
    expected_extensions.all? { |ext| installed.include?(ext) }
  end

  def expected_extensions
    @system.readlines(extensions_file).map(&:strip)
  end

  def install_vscode_extensions
    return unless @system.file_exist?(extensions_file)
    debug "Installing VSCode extensions..."
    installed = installed_extensions
    installed_any = false
    expected_extensions.each do |ext|
      installed_any ||= install_extension_if_missing(ext, installed)
    end
    @installed_extensions = nil if installed_any
  end

  def install_extension_if_missing(extension, installed)
    if installed.include?(extension)
      debug "VSCode extension already installed: #{extension}"
      false
    else
      debug "Installing VSCode extension: #{extension}"
      execute("code --install-extension #{extension}")
      true
    end
  end

  def config_home
    ENV.fetch("XDG_CONFIG_HOME", File.join(@home, ".config"))
  end

  def installed_extensions
    return @installed_extensions if @installed_extensions
    output, = execute("code --list-extensions")
    @installed_extensions = output.split("\n")
  end
end
