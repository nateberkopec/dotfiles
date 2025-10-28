require "yaml"

class Dotfiles
  class Config
    attr_reader :dotfiles_dir
    attr_writer :packages, :paths

    def initialize(dotfiles_dir, system: SystemAdapter.new)
      @dotfiles_dir = dotfiles_dir
      @config_dir = File.join(dotfiles_dir, "config")
      @system = system
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

    def load_config(filename)
      config_path = @system.path_join(@config_dir, filename)
      content = @system.read_file(config_path)
      YAML.safe_load(content, permitted_classes: [Symbol])
    rescue Errno::ENOENT
      {}
    end

    # Allow direct config setting for tests
    def stub_config(filename, content)
      case filename
      when "packages.yml"
        @packages = content
      when "paths.yml"
        @paths = content
      when "config_sync.yml"
        @config_sync = content
      end
    end

    def config_sync
      @config_sync ||= load_config("config_sync.yml")
    end
  end
end
