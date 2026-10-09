class Dotfiles
  class Step
    module Sudoable
      SUDO_MUTEX = Mutex.new

      def self.noninteractive?
        !ENV.fetch("NONINTERACTIVE", "").empty?
      end

      def self.ci_or_noninteractive?
        ENV["CI"] || noninteractive?
      end

      def should_run?
        return false if skip_sudo_step?
        super
      end

      def complete?
        return true if skip_sudo_step?
        super
      end

      def run
        return if skip_sudo_step?
        super
      end

      private

      def execute(command, quiet: true, sudo: false, timeout: nil)
        return super(command, quiet: quiet, timeout: timeout) unless sudo
        return skip_sudo_command(command) if skip_sudo_step?
        execute_with_sudo(command)
      end

      def skip_sudo_command(command)
        debug "Skipping privileged command: #{command}"
        ["", 0]
      end

      def execute_with_sudo(command)
        return run_command(command, quiet: false) if root?
        SUDO_MUTEX.synchronize do
          display_sudo_warning(command) if sudo_authentication_required?
          run_command(Dotfiles::Command.prepend(command, *sudo_prefix), quiet: false)
        end
      end

      def sudo_prefix
        Sudoable.noninteractive? ? ["sudo", "-n"] : ["sudo"]
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
        return true if Sudoable.noninteractive? && !passwordless_sudo?
        return false unless requires_sudo?
        ENV["CI"] || (@system.macos? && !user_has_admin_rights?)
      end

      def passwordless_sudo?
        return @passwordless_sudo unless @passwordless_sudo.nil?
        @passwordless_sudo = root? || run_command(Dotfiles::Command.argv("sudo", "-n", "true"), quiet: true).last == 0
      end

      def requires_sudo?
        self.class.const_defined?(:SUDO_REQUIRED) ? self.class::SUDO_REQUIRED : true
      end
    end
  end
end
