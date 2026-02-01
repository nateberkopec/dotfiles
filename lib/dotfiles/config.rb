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
      {
        "brew" => {"packages" => brew_packages, "casks" => brew_casks},
        "debian" => {"packages" => debian_packages, "sources" => debian_sources},
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
      return package_matrix_from_config if config.key?("packages")
      legacy = config.fetch("brew", {}).fetch("packages", [])
      legacy.map { |pkg| [pkg, nil] }
    end

    def brew_packages
      package_matrix.filter_map { |brew, _debian| brew }.map(&:to_s)
    end

    def debian_packages
      package_matrix.flat_map { |_brew, debian| normalize_debian_entry(debian) }.map(&:to_s)
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

    def package_matrix_from_config
      raw = config.fetch("packages", [])
      case raw
      when Hash
        raw.values.map { |entry| package_pair_from_entry(entry) }
      when Array
        raw
      else
        []
      end
    end

    def package_pair_from_entry(entry)
      case entry
      when Hash
        brew = entry["brew"] || entry[:brew]
        debian = entry["debian"] || entry[:debian]
        [brew, debian]
      when Array
        entry
      else
        [entry, nil]
      end
    end

    def normalize_debian_entry(entry)
      case entry
      when nil, false
        []
      when Array
        entry.compact
      when String
        entry.strip.empty? ? [] : [entry]
      else
        [entry.to_s]
      end
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
