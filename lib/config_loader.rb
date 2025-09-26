class ConfigLoader
  def initialize(dotfiles_dir)
    @dotfiles_dir = dotfiles_dir
    @config_dir = File.join(dotfiles_dir, "config")
  end

  def packages
    @packages ||= load_config("packages.yml")
  end

  def paths
    @paths ||= load_config("paths.yml")
  end

  def expand_path(path_key, category = "home_paths")
    path = paths.dig(category, path_key.to_s)
    return nil unless path
    File.expand_path(path)
  end

  def source_path(source_key)
    source = paths.dig("dotfiles_sources", source_key.to_s)
    return nil unless source
    File.join(@dotfiles_dir, source)
  end

  private

  def load_config(filename)
    config_path = File.join(@config_dir, filename)
    YAML.load_file(config_path)
  rescue Errno::ENOENT
    {}
  end
end
