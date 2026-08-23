#!/usr/bin/env ruby
%w[json toml-rb uri yaml].each { |library| require library }
EXACT_VERSION = /\A\d[\w.+-]*\z/
FUZZY_VERSION = /(?:\A|[.-])(?:latest|lts|x)(?:\z|[.-])/i
base = ARGV.fetch(0)
abort "Expected a commit SHA" unless base.match?(/\A[0-9a-f]{40}\z/)
allowed = %w[.mise.toml Gemfile.lock config/config.yml config/dependency-updater.yml config/mise.version files/home/.config/mise/config.toml files/home/.config/mise/mise.lock files/home/.pi/agent/settings.json]
paths = `git diff --name-only #{base}...HEAD`.lines.map(&:chomp)
abort "Dependency update changed forbidden files: #{paths - allowed}" unless (paths - allowed).empty?

def exact_version(version)
  abort "Dependency versions must be exact: #{version}" unless version.match?(EXACT_VERSION) && !version.match?(FUZZY_VERSION)
  "VERSION"
end

def tools(content)
  data = TomlRB.parse(content)
  data.fetch("tools").transform_values! do |tool|
    tool.is_a?(Hash) ? tool.merge("version" => exact_version(tool.fetch("version"))) : exact_version(tool)
  end
  data
end

def source_identity(url, version)
  uri = URI(url)
  abort "Dependency URLs must use HTTPS" unless uri.scheme == "https"
  path = url[%r{(?:api\.github\.com/repos|github\.com)/([^/]+/[^/]+)}, 1] || uri.path.gsub(version, "VERSION")
  [uri.scheme, uri.host, path]
end

def mise_lock(content)
  data = TomlRB.parse(content)
  data.fetch("tools").each_value do |records|
    records.each do |record|
      version = record.fetch("version")
      record["version"] = exact_version(version)
      record.each_value do |platform|
        next unless platform.is_a?(Hash)
        %w[url url_api].each { |key| platform[key] = source_identity(platform[key], version) if platform[key] }
        checksum = platform["checksum"]
        abort "Dependency checksums must use SHA-256" if checksum && !checksum.match?(/\Asha256:[0-9a-f]{64}\z/)
        platform["checksum"] = "CHECKSUM" if checksum
      end
    end
  end
  data
end

def vscode(content)
  YAML.safe_load(content).tap do |data|
    data.fetch("vscode_extension_sources").each_value do |source|
      version = source.fetch("tag")[/\d+(?:\.\d+)+/]
      abort "VS Code asset does not match its tag" unless version && source.fetch("asset").include?(version)
      %w[tag asset].each { |key| source[key] = source[key].sub(version, "VERSION") }
    end
  end
end

def pi_settings(content)
  JSON.parse(content).tap do |data|
    data.fetch("packages").map! do |package|
      match = package.match(/\A(.+)@(\d[\w.+-]*)\z/) or abort "Pi package versions must be exact"
      "#{match[1]}@#{exact_version(match[2])}"
    end
  end
end

def normalized(path, content)
  return tools(content) if [".mise.toml", "files/home/.config/mise/config.toml"].include?(path)
  return vscode(content) if path == "config/config.yml"
  return YAML.safe_load(content).merge("snoozes" => {}) if path == "config/dependency-updater.yml"
  return exact_version(content.strip) if path == "config/mise.version"
  return pi_settings(content) if path.end_with?("settings.json")
  return [content.scan(/^  remote: .+$/), content.sub(/^GEM\n.*?(?=^PLATFORMS\n)/m, "GEM\nGENERATED\n")] if path == "Gemfile.lock"
  mise_lock(content)
end
paths.each do |path|
  abort "Dependency update made unsafe changes to #{path}" unless normalized(path, `git show #{base}:#{path}`) == normalized(path, File.read(path))
end
