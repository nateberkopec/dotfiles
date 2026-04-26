class Dotfiles
  class Step
    module DebianPackages
      private

      def package_installed?(pkg)
        command_succeeds?(command("dpkg", "-s", pkg))
      end

      def package_available?(pkg)
        command_succeeds?(command("apt-cache", "show", pkg))
      end

      def update_apt
        run_apt("apt-get", "update", "-y")
      end

      def run_apt(*args, retries: 3)
        output = ""
        status = nil

        retries.times do |attempt|
          output, status = execute(sudo_env_command({"DEBIAN_FRONTEND" => "noninteractive"}, *args))
          return [output, status] if status == 0
          break unless apt_retryable_error?(output)
          sleep(3 * (attempt + 1))
        end

        [output, status]
      end

      def apt_retryable_error?(output)
        apt_lock_error?(output) || apt_network_error?(output)
      end

      def apt_lock_error?(output)
        output.include?("Could not get lock") ||
          output.include?("Unable to acquire the dpkg frontend lock") ||
          output.include?("Could not open lock file") ||
          output.include?("Waiting for cache lock")
      end

      def apt_network_error?(output)
        output.include?("Failed to fetch") ||
          output.include?("Unable to fetch some archives") ||
          output.include?("Could not connect to") ||
          output.include?("Connection timed out") ||
          output.include?("Temporary failure resolving")
      end
    end
  end
end
