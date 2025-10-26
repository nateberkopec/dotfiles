require "yaml"

class Dotfiles
  class Config
    attr_reader :dotfiles_dir

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

    def dotfiles_repo
      paths["dotfiles_repo"] || "https://github.com/nateberkopec/dotfiles.git"
    end

    def home
      paths["home"] || ENV["HOME"]
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
