class Dotfiles::Step::FixMiseRubygemsPluginStep < Dotfiles::Step
  def self.display_name
    "Fix Mise RubyGems Plugin"
  end

  def self.depends_on
    [Dotfiles::Step::SyncHomeDirectoryStep]
  end

  def should_run?
    stale_plugin_installed?
  end

  def run
    return unless stale_plugin_installed?

    debug "Removing stale mise RubyGems plugin shim at #{collapse_path_to_home(plugin_path)}..."
    @system.rm_rf(plugin_path)
  end

  def complete?
    super
    !stale_plugin_installed?
  end

  private

  def plugin_path
    File.join(@home, ".local", "share", "mise", "plugins", "ruby", "rubygems-plugin", "rubygems_plugin.rb")
  end

  def stale_plugin_installed?
    return false unless @system.file_exist?(plugin_path)

    content = @system.read_file(plugin_path)
    content.include?("module ReshimInstaller") && content.include?("asdf reshim ruby")
  end
end
