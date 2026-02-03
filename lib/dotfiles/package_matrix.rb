class Dotfiles
  class PackageMatrix
    def initialize(config)
      @config = config
    end

    def matrix
      return package_matrix_from_config if @config.key?("packages")
      legacy = @config.fetch("brew", {}).fetch("packages", [])
      legacy.map { |pkg| [pkg, nil] }
    end

    def brew_packages
      matrix.filter_map { |brew, _debian| brew }.map(&:to_s)
    end

    def debian_packages
      matrix.flat_map { |_brew, debian| normalize_debian_entry(debian) }.map(&:to_s)
    end

    private

    def package_matrix_from_config
      raw = @config.fetch("packages", [])
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
        raise ArgumentError, "Package entry must set brew or debian" if brew.nil? && debian.nil?
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
  end
end
