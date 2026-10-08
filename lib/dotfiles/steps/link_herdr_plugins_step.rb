class Dotfiles::Step::LinkHerdrPluginsStep < Dotfiles::Step
  DESCRIPTION = "Registers local Herdr plugins from their source manifests.".freeze

  def should_run?
    available_plugins.any? && command_exists?("herdr")
  end

  def run
    @link_errors = []
    available_plugins.each do |path|
      link = command("herdr", "plugin", "link", "--enabled", path)
      output, status = execute(link)
      @link_errors << format_command_error(link, status, output) unless status == 0
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

  def plugin_paths
    config.fetch("herdr_plugins", []).map { |path| expand_path_with_home(path) }
  end

  def available_plugins
    plugin_paths.select { |path| @system.file_exist?(File.join(path, "herdr-plugin.toml")) }
  end
end
