require "json"

class Dotfiles::PiNpmOverrides
  def initialize(home:, system:)
    @system = system
    @agent_dir = File.join(home, ".pi", "agent")
  end

  def current?
    return true if expected.empty?

    expected.all? do |name, version|
      manifest.fetch("overrides", {})[name] == version && installed_versions_match?(name, version)
    end
  end

  def apply
    return if expected.empty?

    updated = manifest
    updated["overrides"] = updated.fetch("overrides", {}).merge(expected)
    @system.mkdir_p(npm_dir)
    @system.write_file(manifest_path, JSON.pretty_generate(updated) + "\n")
  end

  def release_age_exclusions
    expected.keys
  end

  private

  def installed_versions_match?(name, version)
    paths = @system.glob(File.join(npm_dir, "node_modules", "**", name, "package.json"), File::FNM_DOTMATCH)
    paths.any? && paths.all? { |path| JSON.parse(@system.read_file(path))["version"] == version }
  end

  def expected
    path = File.join(@agent_dir, "npm-overrides.json")
    @system.file_exist?(path) ? JSON.parse(@system.read_file(path)) : {}
  end

  def manifest
    @system.file_exist?(manifest_path) ? JSON.parse(@system.read_file(manifest_path)) : {}
  end

  def npm_dir
    File.join(@agent_dir, "npm")
  end

  def manifest_path
    File.join(npm_dir, "package.json")
  end
end
