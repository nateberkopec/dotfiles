require "json"
require "toml-rb"
require "yaml"

module DependencyFactory
  Pin = Struct.new(:name, :kind, :manifest, :current, :meta, keyword_init: true)

  module Manifests
    PATHS = %w[.mise.toml files/home/.config/mise/config.toml config/mise.version files/home/.pi/agent/settings.json Gemfile.lock config/config.yml].freeze

    module_function

    def pins(path, content)
      case path
      when /mise\.version\z/ then [Pin.new(name: "mise", kind: "github", manifest: path, current: content.strip, meta: {"repo" => "jdx/mise", "tag_prefix" => "v"})]
      when /\.toml\z/ then mise_tools(path, content)
      when /settings\.json\z/ then pi_packages(path, content)
      when /Gemfile\.lock\z/ then gems(path, content)
      else vscode(path, content)
      end
    end

    def mise_tools(path, content)
      TomlRB.parse(content).fetch("tools", {}).map do |name, spec|
        Pin.new(name: name, kind: "mise", manifest: path, current: spec.is_a?(Hash) ? spec.fetch("version") : spec)
      end
    end

    def pi_packages(path, content)
      JSON.parse(content).fetch("packages").map do |package|
        match = package.match(/\Anpm:(.+)@(\d[\w.+-]*)\z/)
        next Pin.new(name: "pi:#{package}", kind: "unpinned", manifest: path, current: package) unless match
        Pin.new(name: "pi:#{match[1]}", kind: "npm", manifest: path, current: match[2], meta: {"package" => match[1]})
      end
    end

    def gems(path, content)
      specs = content[/^GEM\n.*?(?=^PLATFORMS\n)/m].to_s.scan(/^    (\S+) \((\d[^)]*)\)$/)
      pins = specs.map { |name, version| Pin.new(name: name, kind: "gem", manifest: path, current: version) }
      pins << Pin.new(name: "bundler", kind: "gem", manifest: path, current: content[/^BUNDLED WITH\n\s+(\S+)/, 1])
    end

    def vscode(path, content)
      YAML.safe_load(content).fetch("vscode_extension_sources").map do |id, source|
        version = source.fetch("tag")[/\d+(?:\.\d+)+/]
        prefix = source.fetch("tag").sub(version, "")
        Pin.new(name: "vscode:#{id}", kind: "github", manifest: path, current: version, meta: {"repo" => source.fetch("github"), "tag_prefix" => prefix})
      end
    end
  end
end
