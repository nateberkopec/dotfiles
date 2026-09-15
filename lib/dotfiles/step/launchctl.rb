class Dotfiles
  class Step
    module LaunchCtl
      private

      def load_launchdaemon(plist_path)
        debug "Loading LaunchDaemon..."
        execute(command("launchctl", "bootout", "system", plist_path), sudo: true)
        execute(command("launchctl", "bootstrap", "system", plist_path), sudo: true)
      end
    end
  end
end
