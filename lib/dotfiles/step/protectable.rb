class Dotfiles
  class Step
    module Protectable
      def run
        hook_files.each do |file|
          next unless @system.file_exist?(file)

          _, status = execute("chflags schg '#{file}'", sudo: true)
          add_error("Failed to protect #{file}") unless status == 0
        end
      end

      def complete?
        hook_files.all? { |file| !@system.file_exist?(file) || file_immutable?(file) }
      end

      private

      def file_immutable?(file)
        output, status = execute("ls -lO '#{file}'")
        status == 0 && output.include?("schg")
      end
    end
  end
end
