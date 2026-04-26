require "shellwords"

class Dotfiles
  class Command
    class << self
      def argv(*parts)
        parts.flatten.compact.map(&:to_s)
      end

      def env(vars, *parts)
        [stringify_env(vars), *argv(*parts)]
      end

      def shell(*parts)
        Shellwords.join(argv(*parts))
      end

      def prepend(command, *prefix)
        prefix = argv(*prefix)
        if command.is_a?(Array) && command.first.is_a?(Hash)
          [command.first, *prefix, *command.drop(1)]
        elsif command.is_a?(Array)
          [*prefix, *command]
        else
          [shell(*prefix), command.to_s].reject(&:empty?).join(" ")
        end
      end

      def display(command)
        if command.is_a?(Array) && command.first.is_a?(Hash)
          env_display(command.first, command.drop(1))
        elsif command.is_a?(Array)
          shell(*command)
        else
          command.to_s
        end
      end

      private

      def stringify_env(vars)
        vars.to_h.transform_keys(&:to_s).transform_values(&:to_s)
      end

      def env_display(vars, argv)
        assignments = vars.map { |key, value| "#{key}=#{Shellwords.escape(value)}" }
        [*assignments, shell(*argv)].reject(&:empty?).join(" ")
      end
    end
  end
end
