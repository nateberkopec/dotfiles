require "yaml"

class Dotfiles
  class Config
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

    private

    def load_config(filename)
      config_path = File.join(@config_dir, filename)
      YAML.load_file(config_path)
    rescue Errno::ENOENT
      {}
    end
  end
end
