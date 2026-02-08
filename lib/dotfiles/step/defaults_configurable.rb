class Dotfiles
  class Step
    # Sugar for steps that are fully driven by defaults write/read config.
    #
    # This is intentionally a mixin (not an abstract base class) to keep the
    # step inheritance tree flat and easy to understand.
    module DefaultsConfigurable
      def self.included(base)
        base.include(Defaultable)
        base.macos_only
        base.extend(ClassMethods)
      end

      module ClassMethods
        def defaults_config_key(value = nil)
          return @defaults_config_key if value.nil?
          @defaults_config_key = value
        end

        def defaults_display_name(value = nil)
          return @defaults_display_name || display_name if value.nil?
          @defaults_display_name = value
        end
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
