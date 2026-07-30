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

      def install_plist(plist_path, plist_content)
        debug "Installing plist to #{plist_path}..."
        @system.mkdir_p(File.dirname(plist_path))
        @system.write_file(plist_path, plist_content)
      end

      def load_launchagent(plist_path)
        debug "Loading LaunchAgent..."
        domain = "gui/#{Process.uid}"
        service = "#{domain}/#{File.basename(plist_path, ".plist")}"

        execute(command("launchctl", "bootout", domain, plist_path))
        execute(command("launchctl", "enable", service))
        execute(command("launchctl", "bootstrap", domain, plist_path))
        execute(command("launchctl", "kickstart", "-k", service))
      end

      def load_launchdaemon(plist_path)
        debug "Loading LaunchDaemon..."
        execute(command("launchctl", "bootout", "system", plist_path), sudo: true)
        execute(command("launchctl", "bootstrap", "system", plist_path), sudo: true)
      end

      def script_current?
        file_installed_with_content?(script_path, script_content)
      end

      def launchagent_current?
        file_installed_with_content?(launchagent_path, plist_content)
      end

      def launchagent_loaded?
        command_succeeds?(command("launchctl", "print", "gui/#{Process.uid}/#{launchagent_label}"))
      end

      def launchagent_label
        File.basename(launchagent_path, ".plist")
      end

      def file_installed_with_content?(path, content)
        @system.file_exist?(path) && @system.read_file(path) == content
      end
    end
  end
end
