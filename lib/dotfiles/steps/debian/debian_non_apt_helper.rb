require "securerandom"

class Dotfiles
  class Step
    module DebianNonAptHelper
      private

      def package_installed?(name, command: name)
        bin_paths = [
          File.join(@home, ".local", "bin", command),
          File.join(@home, ".cargo", "bin", command)
        ]
        command_exists?(command) || bin_paths.any? { |path| @system.file_exist?(path) }
      end

      def system_arch
        @system_arch ||= begin
          output, status = @system.execute("uname -m")
          return "" unless status == 0
          output.strip
        end
      end

      def temp_path(label)
        File.join("/tmp", "dotfiles-#{label}-#{SecureRandom.hex(6)}")
      end

      def install_direct_download(name:, url:, error_prefix:, error_message:)
        return if package_installed?(name)
        unless url
          add_error(error_message)
          return
        end
        dest = File.join(@home, ".local", "bin", name)
        download_and_install(url, dest, label: name, error_prefix: error_prefix)
      end

      def download_and_install(url, dest, label:, error_prefix:)
        tmp = temp_path(label)
        output, status = execute("curl -fsSL #{url} -o #{tmp}")
        if status != 0
          add_error("#{error_prefix} download failed (status #{status}): #{output}")
          @system.rm_rf(tmp)
          return false
        end
        @system.mkdir_p(File.dirname(dest))
        output, status = execute("install -m 755 #{tmp} #{dest}")
        @system.rm_rf(tmp)
        add_error("#{error_prefix} install failed (status #{status}): #{output}") unless status == 0
        status == 0
      end
    end
  end
end
