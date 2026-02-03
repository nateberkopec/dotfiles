class Dotfiles
  class Step
    module DebianPackages
      private

      def package_installed?(pkg)
        command_succeeds?("dpkg -s #{pkg} >/dev/null 2>&1")
      end

      def package_available?(pkg)
        command_succeeds?("apt-cache show #{pkg} >/dev/null 2>&1")
      end

      def update_apt
        execute("#{sudo_prefix}DEBIAN_FRONTEND=noninteractive apt-get update -y")
      end
    end
  end
end
