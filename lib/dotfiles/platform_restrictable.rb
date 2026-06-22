class Dotfiles
  # Marks a class as restricted to a platform. Extend this module in a
  # Step or Migration base class to get macos_only/debian_only DSL and
  # predicates. The includer's instances are expected to provide
  # `@system` (responding to #macos?/#debian?) for allowed_on_platform?.
  module PlatformRestrictable
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
  end
end
