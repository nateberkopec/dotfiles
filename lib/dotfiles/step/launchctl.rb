class Dotfiles
  class Step
    module LaunchCtl
      private

      def install_script(script_path, script_content)
        debug "Installing script to #{script_path}..."
        @system.mkdir_p(File.dirname(script_path))
        @system.write_file(script_path, script_content)
        @system.chmod(0o755, script_path)
      end

      def load_launchdaemon(plist_path)
        debug "Loading LaunchDaemon..."
        execute(command("launchctl", "bootout", "system", plist_path), sudo: true)
        execute(command("launchctl", "bootstrap", "system", plist_path), sudo: true)
      end
    end
  end
end
