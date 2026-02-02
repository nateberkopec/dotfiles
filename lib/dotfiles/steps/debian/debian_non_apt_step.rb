class Dotfiles
  class Step
    module DebianNonAptStep
      def self.included(base)
        base.include(Dotfiles::Step::DebianNonAptHelper)
        base.extend(ClassMethods)
        base.debian_only
      end

      module ClassMethods
        def depends_on
          [Dotfiles::Step::InstallDebianPackagesStep]
        end
      end

      def should_run?
        allowed_on_platform? && configured? && !installed?
      end

      def run
        install if configured?
      end

      def complete?
        super
        return true unless configured?
        return true if installed?
        add_error("Non-APT package not installed: #{package_name}")
        false
      end

      private

      def configured?
        @config.debian_non_apt_packages.include?(package_name)
      end

      def installed?
        package_installed?(package_name, command: command_name)
      end

      def command_name
        package_name
      end

      def package_name
        raise NotImplementedError, "Subclasses must implement #package_name"
      end

      def install
        raise NotImplementedError, "Subclasses must implement #install"
      end
    end
  end
end
