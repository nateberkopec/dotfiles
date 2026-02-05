class Dotfiles
  class Step
    class DefaultsStep < Step
      @@steps.delete(self)

      include Defaultable

      def self.macos_only?
        true
      end

      def self.defaults_config_key(key = nil)
        key ? @defaults_config_key = key : @defaults_config_key
      end

      def self.defaults_display_name(name = nil)
        name ? @defaults_display_name = name : (@defaults_display_name || display_name)
      end

      def run
        run_defaults_write
        after_defaults_write
      end

      def complete?
        super
        defaults_complete?(self.class.defaults_display_name)
      end

      def update
        update_defaults_config(self.class.defaults_config_key)
      end

      private

      def config_key
        self.class.defaults_config_key
      end

      def after_defaults_write
      end
    end
  end
end
