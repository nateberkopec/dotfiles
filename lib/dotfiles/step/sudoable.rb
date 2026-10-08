class Dotfiles
  class Step
    module Sudoable
      SUDO_MUTEX = Mutex.new

      def should_run?
        return false if skip_sudo_step?
        super
      end

      def complete?
        return true if skip_sudo_step?
        super
      end

      private

      def execute(command, quiet: true, sudo: false)
        return super(command, quiet: quiet) unless sudo
        return skip_sudo_command(command) if ci_or_noninteractive?
        execute_with_sudo(command)
      end

      def skip_sudo_command(command)
        debug "Skipping sudo command in CI/non-interactive environment: #{command}"
        ["", 0]
      end

      def execute_with_sudo(command)
        SUDO_MUTEX.synchronize do
          display_sudo_warning(command) if sudo_authentication_required?
          run_command(Dotfiles::Command.prepend(command, "sudo"), quiet: false)
        end
      end

      def sudo_authentication_required?
        output, status = run_command(Dotfiles::Command.argv("sudo", "-n", "-v"), quiet: true)
        status != 0 && output.include?("password is required")
      end

      def display_sudo_warning(command)
        step_name = self.class.name.gsub(/Step$/, "").gsub(/([A-Z])/, ' \1').strip
        @system.execute(
          Dotfiles::Command.argv(
            "gum", "style",
            "--foreground", "#ff6b6b",
            "--border", "double",
            "--align", "center",
            "--width", "50",
            "--margin", "1 0",
            "--padding", "1 2",
            "🔒 Admin Privileges Required",
            step_name,
            "",
            "Command: #{Dotfiles::Command.display(command)}",
            "",
            "This is required to complete setup"
          ),
          quiet: false
        )
      end

      def skip_sudo_step?
        ci_or_noninteractive? || (@system.macos? && !user_has_admin_rights?)
      end

      def ci_or_noninteractive?
        ENV["DOTF_NO_SUDO"] == "1" || ENV["CI"] || ENV["NONINTERACTIVE"]
      end
    end
  end
end
