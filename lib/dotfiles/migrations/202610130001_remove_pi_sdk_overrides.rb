require "json"

class Dotfiles::Migration::RemovePiSdkOverrides < Dotfiles::Migration
  VERSION = 202610130001

  def up
    agent_dir = File.join(@home, ".pi", "agent")
    remove_managed_pins(File.join(agent_dir, "npm", "package.json"))
    @system.rm_rf(File.join(agent_dir, "npm-overrides.json"))
  end

  def down
    raise NotImplementedError, "This migration retires SDK overrides and cannot be safely reversed."
  end

  private

  def remove_managed_pins(path)
    return unless @system.file_exist?(path)

    manifest = JSON.parse(@system.read_file(path))
    overrides = manifest.fetch("overrides", {})
    remaining = overrides.reject do |name, version|
      ["@modelcontextprotocol/client", "@modelcontextprotocol/core"].include?(name) && version == "2.2.0"
    end
    return if remaining == overrides

    if remaining.empty?
      manifest.delete("overrides")
    else
      manifest["overrides"] = remaining
    end
    @system.write_file(path, "#{JSON.pretty_generate(manifest)}\n")
  end
end
