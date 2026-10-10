require "json"

class Dotfiles::Step::LinkHerdrPluginsStep < Dotfiles::Step
  DESCRIPTION = "Registers local Herdr plugins from their source manifests.".freeze

  def should_run?
    available_plugins.any? && command_exists?("herdr") && pending_plugins.any?
  end

  def run
    @link_errors = []
    pending_plugins.each do |path|
      link = command("herdr", "plugin", "link", path, "--enabled")
      output, status = execute(link)
      if status == 0
        record_manifest(path)
        next
      end

      @link_errors << "Failed to link Herdr plugin: #{collapse_path_to_home(path)}\n" \
        "Exit status: #{status}\n#{output.to_s.strip}\nCommand: #{Dotfiles::Command.display(link)}"
    end
  end

  def complete?
    super
    missing = plugin_paths - available_plugins
    missing.each do |path|
      add_notice(title: "Herdr plugin source unavailable", message: "Skipping #{path}; restore the local checkout and run dotf again.")
    end
    if available_plugins.any? && !command_exists?("herdr")
      add_notice(title: "Herdr unavailable", message: "Install Herdr and run dotf again to register local plugins.")
    end
    Array(@link_errors).each { |message| add_error(message) }
    @errors.empty?
  end

  private

  def record_manifest(path)
    @system.mkdir_p(File.dirname(fingerprint_path(path)))
    @system.write_file(fingerprint_path(path), file_hash(File.join(path, "herdr-plugin.toml")))
  end

  def pending_plugins
    installed = installed_plugins
    available_plugins.reject do |path|
      installed.any? { |plugin| registered?(plugin, path) } && manifest_current?(path)
    end
  end

  def installed_plugins
    output, status = execute(command("herdr", "plugin", "list", "--json"))
    return [] unless status == 0

    JSON.parse(output).fetch("result").fetch("plugins")
  rescue JSON::ParserError, KeyError
    []
  end

  def registered?(plugin, path)
    plugin["plugin_root"] == path && plugin["manifest_path"] == File.join(path, "herdr-plugin.toml") &&
      plugin["enabled"] == true && plugin.dig("source", "kind") == "local"
  end

  def manifest_current?(path)
    stamp = fingerprint_path(path)
    @system.file_exist?(stamp) && @system.read_file(stamp) == file_hash(File.join(path, "herdr-plugin.toml"))
  end

  def fingerprint_path(path)
    File.join(@home, ".local", "state", "dotfiles", "herdr-plugins", Digest::SHA256.hexdigest(path))
  end

  def plugin_paths
    config.fetch("herdr_plugins", []).map do |path|
      expanded = expand_path_with_home(path)
      @system.dir_exist?(expanded) ? @system.realpath(expanded) : expanded
    end.uniq
  end

  def available_plugins
    plugin_paths.select { |path| @system.file_exist?(File.join(path, "herdr-plugin.toml")) }
  end
end
