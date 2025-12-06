require "yaml"

class Dotfiles
  class Config
    attr_reader :dotfiles_dir
    attr_writer :config

    def initialize(dotfiles_dir, system: SystemAdapter.new)
      @dotfiles_dir = dotfiles_dir
      @config_dir = File.join(dotfiles_dir, "config")
      @system = system
    end

    def config
      @config ||= load_config
    end

    def packages
      {"brew" => config.fetch("brew", {}), "applications" => config.fetch("applications", [])}
    end

    def packages=(hash)
      @config ||= {}
      @config["brew"] = hash["brew"] if hash.key?("brew")
      @config["applications"] = hash["applications"] if hash.key?("applications")
    end

    def dotfiles_repo
      config["dotfiles_repo"] || "https://github.com/nateberkopec/dotfiles.git"
    end

    def home
      config["home"] || ENV["HOME"]
    end

    def unmanaged_apps
      config.fetch("unmanaged_apps", [])
    end

    def unmanaged_apps=(list)
      @config ||= {}
      @config["unmanaged_apps"] = list
    end

    def [](key)
      config[key]
    end

    def fetch(key, default = nil)
      config.fetch(key, default)
    end

    private

    def load_config
      config_path = File.join(@config_dir, "config.yml")
      content = @system.read_file(config_path)
      YAML.safe_load(content, permitted_classes: [Symbol])
    rescue Errno::ENOENT
      {}
    end
  end
end
