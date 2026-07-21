require "json"

class Dotfiles::Step::InstallPiPackagesStep < Dotfiles::Step
  DESCRIPTION = "Installs Pi packages pinned in Pi settings.".freeze

  def self.depends_on
    [Dotfiles::Step::InstallMiseToolsStep, Dotfiles::Step::SyncHomeDirectoryStep]
  end

  def should_run?
    pi_available? && missing_packages.any?
  end

  def run
    @install_errors = []
    missing_packages.each { |package| install_package(package) }
  end

  def complete?
    super
    return true unless settings_exist?
    unless pi_available?
      add_error("pi not available; cannot install Pi packages")
      return false
    end

    install_errors.each { |message| add_error(message) }
    missing_packages.each { |package| add_error("Pi package not installed: #{package}") }
    @errors.empty?
  end

  private

  def install_package(package)
    output, status = execute(command("pi", "install", package))
    install_errors << format_command_error(command("pi", "install", package), status, output) unless status == 0
  end

  def missing_packages
    expected_packages.reject { |package| package_installed?(package) }
  end

  def package_installed?(package)
    npm_package = package.match(/\Anpm:(.+)@([^@]+)\z/)
    return installed_packages.include?(package) unless npm_package

    installed_npm_version(npm_package[1]) == npm_package[2]
  end

  def installed_npm_version(package)
    path = File.join(@home, ".pi", "agent", "npm", "node_modules", package, "package.json")
    return unless @system.file_exist?(path)

    JSON.parse(@system.read_file(path))["version"]
  rescue JSON::ParserError
    nil
  end

  def expected_packages
    return [] unless settings_exist?

    JSON.parse(@system.read_file(settings_path)).fetch("packages", [])
  rescue JSON::ParserError
    []
  end

  def installed_packages
    return [] unless pi_available?

    output, status = execute(command("pi", "list"))
    return [] unless status == 0

    output.lines.map(&:strip).grep(/^\S+$/)
  end

  def install_errors
    @install_errors ||= []
  end

  def settings_exist?
    @system.file_exist?(settings_path)
  end

  def settings_path
    File.join(@home, ".pi", "agent", "settings.json")
  end

  def pi_available?
    command_exists?("pi")
  end
end
