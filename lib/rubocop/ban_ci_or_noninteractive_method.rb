module RuboCop
  module Cop
    module Dotfiles
      class BanCiOrNoninteractiveMethod < Base
        MSG = "Do not define ci_or_noninteractive? outside lib/dotfiles/step/sudoable.rb"

        def on_def(node)
          return unless node.method_name == :ci_or_noninteractive?
          add_offense(node) unless allowed_file?
        end

        def on_defs(node)
          return unless node.method_name == :ci_or_noninteractive?
          add_offense(node) unless allowed_file?
        end

        private

        def allowed_file?
          processed_source&.file_path&.end_with?("lib/dotfiles/step/sudoable.rb")
        end
      end
    end
  end
end
