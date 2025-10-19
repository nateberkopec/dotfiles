require "yaml"

class Dotfiles
  class Config
    attr_reader :dotfiles_dir, :home_directory, :debug

    def initialize(dotfiles_dir, home_directory: ENV["HOME"], debug: ENV["DEBUG"] == "true")
      @dotfiles_dir = dotfiles_dir
      @home_directory = home_directory
      @debug = debug
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

    private

    def load_config(filename)
      config_path = File.join(@config_dir, filename)
      YAML.load_file(config_path)
    rescue Errno::ENOENT
      {}
    end
  end
end
