require "json"

class Dotfiles::Step::InstallPaseoPluginsStep < Dotfiles::Step
  DESCRIPTION = "Installs the Paseo plugins pinned in config.yml.".freeze

  macos_only

  def should_run?
    command_exists?("paseo") && missing_plugins.any?
  end

  def run
    @install_errors = []
    missing_plugins.each do |id, plugin|
      install = command("paseo", "plugin", "install", plugin.fetch("source"), "--ref", plugin.fetch("ref"), "--id", id)
      output, status = execute(install)
      @install_errors << format_command_error(install, status, output) unless status == 0
    end
  end

  def complete?
    super
    return true if plugins.empty?
    unless command_exists?("paseo")
      add_notice(title: "Paseo unavailable", message: "Install Paseo and run dotf again to install its plugins.")
      return true
    end

    Array(@install_errors).each { |message| add_error(message) }
    missing_plugins.each_key { |id| add_error("Paseo plugin not installed: #{id}") }
    @errors.empty?
  end

  private

  def plugins
    @config.fetch("paseo_plugins", {})
  end

  def missing_plugins
    plugins.except(*installed_plugin_ids)
  end

  def installed_plugin_ids
    output, status = execute(command("paseo", "plugin", "ls", "--json"))
    return [] unless status == 0

    JSON.parse(output).map { |plugin| plugin.fetch("id") }
  rescue JSON::ParserError, KeyError
    []
  end
end
