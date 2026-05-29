require "uri"

class Dotfiles::Step::VSCodeConfigurationStep < Dotfiles::Step
  DESCRIPTION = "Installs configured VS Code extensions when the code CLI is available.".freeze

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
    expected_extensions.all? { |ext| installed.include?(ext[:id]) }
  end

  def expected_extensions
    @system.readlines(extensions_file).filter_map do |line|
      parse_extension_line(line.strip)
    end
  end

  def install_vscode_extensions
    return unless @system.file_exist?(extensions_file)
    debug "Installing VSCode extensions..."
    missing = expected_extensions.reject { |ext| installed_extensions.include?(ext[:id]) }
    missing.each { |ext| install_extension(ext) }
    @installed_extensions = nil if missing.any?
  end

  def parse_extension_line(line)
    return if line.empty?
    id, source = line.split(/\s+/, 2)
    {id: id, source: source}
  end

  def install_extension(ext)
    debug "Installing VSCode extension: #{ext[:id]}"
    execute(command("code", "--install-extension", install_arg_for(ext)))
  end

  def install_arg_for(ext)
    source = ext[:source].to_s
    return ext[:id] if source.empty?
    return downloaded_extension(source) if source.start_with?("http://", "https://")

    source
  end

  def downloaded_extension(url)
    dir = temp_path("vscode-extension")
    path = File.join(dir, File.basename(URI.parse(url).path))
    @system.mkdir_p(dir)
    execute(command("curl", "-fsSL", url, "-o", path))
    path
  end

  def config_home
    ENV.fetch("XDG_CONFIG_HOME", File.join(@home, ".config"))
  end

  def installed_extensions
    return @installed_extensions if @installed_extensions
    output, = execute(command("code", "--list-extensions"))
    @installed_extensions = output.split("\n")
  end
end
