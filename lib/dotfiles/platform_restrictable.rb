class Dotfiles
  # Marks a class as restricted to a platform. Extend this module in a
  # Step or Migration base class to get macos_only/debian_only DSL and
  # predicates. The includer's instances are expected to provide
  # `@system` (responding to #macos?/#debian?) for allowed_on_platform?.
  module PlatformRestrictable
    def self.extended(base)
      base.include InstanceMethods
    end

    def macos_only
      @macos_only = true
    end

    def macos_only?
      @macos_only || false
    end

    def debian_only
      @debian_only = true
    end

    def debian_only?
      @debian_only || false
    end

    module InstanceMethods
      def allowed_on_platform?
        (!self.class.macos_only? || @system.macos?) &&
          (!self.class.debian_only? || @system.debian?)
      end
    end
  end
end
