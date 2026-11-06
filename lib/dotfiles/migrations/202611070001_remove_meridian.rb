require "json"

class Dotfiles::Migration::RemoveMeridian < Dotfiles::Migration
  VERSION = 202611070001
  TOOL = "npm:@rynfar/meridian".freeze
  LABEL = "dev.mise.meridian".freeze

  def up
    remove_launch_agent if @system.macos?
    agent_dir = File.join(@home, ".pi", "agent")
    remove_provider(File.join(agent_dir, "models.json"), "providers")
    remove_provider(File.join(agent_dir, "auth.json"))
    retired_paths(agent_dir).each { |path| @system.rm_rf(path) }
    execute(command("mise", "--cd", @home, "uninstall", "--yes", "--all", TOOL)) if tool_installed?
  end

  def down
    raise NotImplementedError, "This migration removes the retired Meridian proxy and cannot be safely reversed."
  end

  private

  def remove_launch_agent
    execute(shell_script('launchctl bootout "gui/$(id -u)/$1" 2>/dev/null || true', LABEL))
    @system.rm_rf(File.join(@home, "Library", "LaunchAgents", "#{LABEL}.plist"))
  end

  def remove_provider(path, key = nil)
    return unless @system.file_exist?(path)

    data = JSON.parse(@system.read_file(path))
    container = key ? data.fetch(key, {}) : data
    return unless container.delete("meridian")

    if key && container.empty? && data.keys == [key]
      @system.rm_rf(path)
    else
      @system.write_file(path, "#{JSON.pretty_generate(data)}\n")
    end
  end

  def retired_paths(agent_dir)
    [
      File.join(agent_dir, "extensions", "meridian"),
      File.join(@home, ".local", "share", "meridian"),
      File.join(@home, ".config", "meridian"),
      File.join(@home, ".cache", "meridian"),
      File.join(@home, "Library", "Logs", "meridian.out.log"),
      File.join(@home, "Library", "Logs", "meridian.err.log")
    ]
  end

  def tool_installed?
    command_exists?("mise") && command_succeeds?(command("mise", "--cd", @home, "where", TOOL))
  end
end
