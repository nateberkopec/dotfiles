require "securerandom"
require "shellwords"

class Dotfiles
  class Step
    module LaunchCtl
      private

      def install_script(script_path, script_content, mode: 0o755)
        debug "Installing script to #{script_path}..."
        @system.mkdir_p(File.dirname(script_path))
        @system.write_file(script_path, script_content)
        @system.chmod(mode, script_path)
      end

      def install_plist(plist_path, plist_content, sudo: false)
        debug "Installing plist to #{plist_path}..."
        @system.mkdir_p(File.dirname(plist_path))
        if sudo
          temp_path = File.join("/tmp", "dotfiles-plist-#{SecureRandom.hex(6)}.plist")
          @system.write_file(temp_path, plist_content)
          execute(command("install", "-m", "644", temp_path, plist_path), sudo: true)
          @system.rm_rf(temp_path)
        else
          @system.write_file(plist_path, plist_content)
        end
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

      def script_installed?(script_path)
        @system.file_exist?(script_path)
      end

      def plist_installed?(plist_path)
        @system.file_exist?(plist_path)
      end
    end
  end
end
