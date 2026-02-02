require "yaml"
require "package_matrix"

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
      matrix = PackageMatrix.new(config)
      {
        "brew" => {"packages" => matrix.brew_packages, "casks" => brew_casks},
        "debian" => {"packages" => matrix.debian_packages, "sources" => debian_sources},
        "applications" => applications
      }
    end

    def packages=(hash)
      @config ||= {}
      @config["brew"] = hash["brew"] if hash.key?("brew")
      @config["packages"] = hash["packages"] if hash.key?("packages")
      @config["debian_non_apt_packages"] = hash["debian_non_apt_packages"] if hash.key?("debian_non_apt_packages")
      @config["debian_sources"] = hash["debian_sources"] if hash.key?("debian_sources")
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

    def package_matrix
      PackageMatrix.new(config).matrix
    end

    def brew_packages
      PackageMatrix.new(config).brew_packages
    end

    def debian_packages
      PackageMatrix.new(config).debian_packages
    end

    def debian_sources
      config.fetch("debian_sources", [])
    end

    def debian_non_apt_packages
      config.fetch("debian_non_apt_packages", []).map(&:to_s)
    end

    def applications
      config.fetch("applications", [])
    end

    def applications=(apps)
      @config ||= {}
      @config["applications"] = apps
    end

    def brew_casks
      config.fetch("brew", {}).fetch("casks", [])
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
