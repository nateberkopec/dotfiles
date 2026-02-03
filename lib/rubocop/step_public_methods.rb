module RuboCop
  module Cop
    module Dotfiles
      class StepPublicMethods < Base
        MSG = "Step classes should only have these public methods: run, complete?, update, should_run?. Make '%<method>s' private or remove it."

        ALLOWED_PUBLIC_METHODS = %i[
          run
          complete?
          update
          should_run?
          initialize
        ].freeze

        def on_class(node)
          return unless step_file?
          return unless inherits_from_step?(node)

          check_public_methods(node)
        end

        private

        def step_file?
          processed_source&.file_path&.include?("lib/dotfiles/steps/")
        end

        def inherits_from_step?(node)
          return false unless node.parent_class

          parent = node.parent_class
          return false unless parent.is_a?(RuboCop::AST::ConstNode)

          parent.const_name&.include?("Step")
        end

        def check_public_methods(class_node)
          visibility = :public
          body = class_node.body
          return unless body

          # Handle both direct children and those wrapped in a begin node
          nodes = body.begin_type? ? body.children : [body]

          nodes.each do |node|
            # Track visibility changes
            if node.send_type? && %i[private protected public].include?(node.method_name)
              visibility = node.method_name
              next
            end

            # Only check instance method definitions
            next unless node.def_type?
            next if visibility != :public

            method_name = node.method_name
            next if ALLOWED_PUBLIC_METHODS.include?(method_name)

            add_offense(node, message: format(MSG, method: method_name))
          end
        end
      end
    end
  end
end
