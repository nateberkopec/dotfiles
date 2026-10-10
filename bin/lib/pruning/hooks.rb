require "open3"

module ManagedPruning
  class Hooks
    def validate(hook)
      return unless hook
      raise "Unknown pruning hook" unless hook.keys.sort == ["label", "type"] && hook.fetch("type") == "launch_agent"
      raise "Invalid LaunchAgent label" unless hook.fetch("label").match?(/\Adev\.mise\.[a-z0-9-]+\z/)
    end

    def artifacts(hook)
      hook ? ["Library/LaunchAgents/#{hook.fetch("label")}.plist"] : []
    end

    def run(hook)
      return unless hook
      validate(hook)
      return unless RUBY_PLATFORM.include?("darwin")

      target = "gui/#{Process.uid}/#{hook.fetch("label")}"
      output, status = Open3.capture2e("launchctl", "print", target)
      unless status.success?
        return if output.include?("Could not find service")
        raise "Cannot inspect #{target}: #{output}"
      end
      output, status = Open3.capture2e("launchctl", "bootout", target)
      raise "Cannot unload #{target}: #{output}" unless status.success?
      puts "Unloaded #{hook.fetch("label")}"
    end
  end
end
