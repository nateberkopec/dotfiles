class Dotfiles::Step::VSCodeConfigurationStep < Dotfiles::Step
  DESCRIPTION = "Installs configured VS Code extensions when the code CLI is available.".freeze

  def self.display_name
    "VS Code Configuration"
  end

  def run
    install_vscode_extensions
  end

  def complete?
    super
    unless extensions_installed?
      install_errors.each { |error| add_error(error) }
      add_error("VSCode extensions not fully installed")
    end
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
    expected_extensions.all? { |ext| extension_installed?(ext) }
  end

  def expected_extensions
    @system.readlines(extensions_file).map(&:strip).reject(&:empty?)
  end

  def install_vscode_extensions
    return unless @system.file_exist?(extensions_file)
    install_errors.clear
    debug "Installing VSCode extensions..."
    missing = expected_extensions.reject { |ext| extension_installed?(ext) }
    missing.each { |ext| install_extension(ext) }
  end

  def install_extension(extension_id)
    source = vscode_extension_sources[extension_id]
    return install_marketplace_extension(extension_id) unless source

    install_github_vsix_extension(extension_id, source)
  end

  def install_marketplace_extension(extension_id)
    debug "Installing VSCode extension: #{extension_id}"
    execute_install(command("code", "--install-extension", extension_id))
  end

  def install_github_vsix_extension(extension_id, source)
    return record_install_error("gh CLI is required to install #{extension_id} from GitHub release assets") unless command_exists?("gh")

    vsix_path = download_github_vsix(extension_id, source)
    execute_install(command("code", "--install-extension", vsix_path)) if vsix_path
  end

  def download_github_vsix(extension_id, source)
    @system.mkdir_p(vsix_cache_dir)
    download_command = command("gh", "release", "download", source.fetch("tag"), "-R", source.fetch("github"), "-p", source.fetch("asset"), "-D", vsix_cache_dir, "--clobber")
    output, status = execute(download_command)
    return File.join(vsix_cache_dir, source.fetch("asset")) if status == 0

    record_install_error(format_command_error(download_command, status, output))
    nil
  end

  def execute_install(install_command)
    output, status = execute(install_command)
    record_install_error(format_command_error(install_command, status, output)) unless status == 0
  end

  def record_install_error(message)
    install_errors << message
    add_error(message)
  end

  def install_errors
    @install_errors ||= []
  end

  def vscode_extension_sources
    @config.fetch("vscode_extension_sources", {})
  end

  def vsix_cache_dir
    File.join("/tmp", "dotfiles-vscode-extensions")
  end

  def config_home
    ENV.fetch("XDG_CONFIG_HOME", File.join(@home, ".config"))
  end

  def extensions_dir
    File.join(@home, ".vscode", "extensions")
  end

  def extension_installed?(extension_id)
    @system.glob(File.join(extensions_dir, "#{extension_id}-*")).any? { |path| @system.dir_exist?(path) }
  end
end
