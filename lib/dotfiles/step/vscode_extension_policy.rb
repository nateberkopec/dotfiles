require "json"

class Dotfiles
  class Step
    module VSCodeExtensionPolicy
      private

      def policy_allowed_extensions(extensions)
        policy = managed_extension_policy
        return extensions unless policy.is_a?(Hash)

        policy = policy.transform_keys(&:downcase)
        extensions.select do |extension|
          id = extension.downcase
          rule = policy.fetch(id) { policy.fetch(id.split(".").first) { policy.fetch("*", false) } }
          rule != false
        end
      end

      def managed_extension_policy
        path = "/Library/Managed Preferences/com.vscode.plist"
        return unless @system.macos? && @system.file_exist?(path)

        read_command = command("plutil", "-convert", "json", "-o", "-", path)
        output, status = execute(read_command)
        raise format_command_error(read_command, status, output) unless status == 0

        policy = JSON.parse(output)["AllowedExtensions"]
        policy.is_a?(String) ? JSON.parse(policy) : policy
      end
    end
  end
end
