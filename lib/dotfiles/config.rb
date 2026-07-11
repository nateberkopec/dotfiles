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

    def dotfiles_repo
      config["dotfiles_repo"] || "https://github.com/nateberkopec/dotfiles.git"
    end

    def home
      config["home"] || ENV["HOME"]
    end

    def [](key)
      config[key]
    end

    def fetch(key, default = nil)
      config.fetch(key, default)
    end

    def brew_casks
      env_csv("BREW_CI_CASKS") || config.fetch("brew_casks", [])
    end

    def debian_desktop_apps
      selected = env_csv("DEBIAN_CI_DESKTOP_APPS")
      apps = config.fetch("debian_desktop_apps", [])
      return apps unless selected

      apps.select { |app| selected.include?(app["name"].to_s) }
    end

    def debian_non_apt_packages
      packages = env_csv("DEBIAN_CI_NON_APT_PACKAGES") || config.fetch("debian_non_apt_packages", [])
      packages.map(&:to_s)
    end

    private

    def env_csv(name)
      return nil unless ENV.key?(name)

      ENV.fetch(name).split(",").map(&:strip).reject(&:empty?)
    end

    def load_config
      config_path = File.join(@config_dir, "config.yml")
      content = @system.read_file(config_path)
      YAML.safe_load(content, permitted_classes: [Symbol])
    rescue Errno::ENOENT
      {}
    end
  end
end
