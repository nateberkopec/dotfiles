class Dotfiles
  class Step
    module Protectable
      def run
        protected_files.each do |file|
          protect_file(file) if @system.file_exist?(file)
        end
      end

      def complete?
        super
        protected_files.all? { |file| !@system.file_exist?(file) || file_protected?(file) }
      end

      private

      def protect_file(file)
        mode = protected_file_mode(file)
        @system.chmod(mode, file) if mode

        _, status = execute(command("chflags", immutable_flag(file), file), quiet: false, sudo: protect_with_sudo?(file))
        add_error("Failed to protect #{file}") unless status == 0
      end

      def file_protected?(file)
        file_immutable?(file) && file_mode_matches?(file)
      end

      def file_immutable?(file)
        file_metadata(command("ls", "-lO", file))&.include?(immutable_flag(file))
      end

      def file_mode_matches?(file)
        mode = protected_file_mode(file)
        return true unless mode

        file_metadata(command("stat", "-f", "%Lp", file)) == format("%o", mode)
      end

      def file_metadata(command)
        output, status = execute(command)
        return output if status == 0

        nil
      end

      def protected_files
        []
      end

      def immutable_flag(_file)
        "schg"
      end

      def protect_with_sudo?(_file)
        true
      end

      def protected_file_mode(_file)
        nil
      end
    end
  end
end
