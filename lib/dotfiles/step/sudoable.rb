class Dotfiles
  class Step
    module Sudoable
      def should_run?
        return false if ci_or_noninteractive?
        super
      end

      def complete?
        return true if ci_or_noninteractive?
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
        display_sudo_warning(command)
        run_command(Dotfiles::Command.prepend(command, "sudo"), quiet: false)
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

      def ci_or_noninteractive?
        ENV["CI"] || ENV["NONINTERACTIVE"]
      end
    end
  end
end
