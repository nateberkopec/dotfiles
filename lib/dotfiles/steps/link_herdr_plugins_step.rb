require "json"

class Dotfiles::Step::LinkHerdrPluginsStep < Dotfiles::Step
  DESCRIPTION = "Links the Herdr plugins deployed from dotfiles.".freeze

  def should_run?
    command_exists?("herdr") && pending_plugins.any?
  end

  def run
    @link_errors = []
    pending_plugins.each do |path|
      link = command("herdr", "plugin", "link", path, "--enabled")
      output, status = execute(link)
      @link_errors << format_command_error(link, status, output) unless status == 0
    end
  end

  def complete?
    super
    return true if plugin_paths.empty?
    unless command_exists?("herdr")
      add_notice(title: "Herdr unavailable", message: "Install Herdr and run dotf again to link its plugins.")
      return true
    end

    Array(@link_errors).each { |message| add_error(message) }
    pending_plugins.each { |path| add_error("Herdr plugin not linked: #{collapse_path_to_home(path)}") }
    @errors.empty?
  end

  private

  def plugin_paths
    manifests = @system.glob(File.join(@home, ".local", "share", "dotfiles", "herdr-plugins", "*", "herdr-plugin.toml"))
    manifests.sort.map { |manifest| File.dirname(manifest) }
  end

  def pending_plugins
    linked = linked_plugin_roots
    plugin_paths.reject { |path| linked.include?(path) }
  end

  def linked_plugin_roots
    output, status = execute(command("herdr", "plugin", "list", "--json"))
    return [] unless status == 0

    plugins = JSON.parse(output).fetch("result").fetch("plugins")
    plugins.select { |plugin| plugin["enabled"] && plugin.dig("source", "kind") == "local" }.map { |plugin| plugin["plugin_root"] }
  rescue JSON::ParserError, KeyError
    []
  end
end
