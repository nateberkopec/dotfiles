class Dotfiles
  class Step
    module DmgInstallable
      private

      def install_dmg_app
        image = temp_path("#{app_name.downcase}-release.dmg")
        download_image(image)
        install_app(image)
      ensure
        @system.rm_rf(image) if image
      end

      def download_image(image)
        _output, status = execute(command("curl", "-fsSL", "--retry", "2", "-o", image, self.class::URL))
        raise "Failed to download #{app_name} release" unless status == 0

        output, status = execute(command("/usr/bin/shasum", "-a", "256", image))
        raise "#{app_name} release checksum mismatch" unless status == 0 && output.split.first == self.class::SHA256
      end

      def install_app(image)
        mountpoint = temp_path("#{app_name.downcase}-mount")
        @mounted = false
        @system.mkdir_p(mountpoint)
        mount_image(image, mountpoint)
        copy_app(mountpoint)
      ensure
        if @mounted
          unmount_image(mountpoint)
          @system.rm_rf(mountpoint)
        end
      end

      def mount_image(image, mountpoint)
        _output, status = execute(command("/usr/bin/hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", mountpoint, image))
        raise "Failed to mount #{app_name} release" unless status == 0
        @mounted = true
      end

      def copy_app(mountpoint)
        source = File.join(mountpoint, "#{app_name}.app")
        _output, status = execute(command("/usr/bin/codesign", "--verify", "--deep", "--strict", source))
        raise "#{app_name} release signature is invalid" unless status == 0

        _output, status = execute(command("/usr/bin/ditto", source, destination))
        raise "Failed to copy #{app_name} release" unless status == 0
      end

      def unmount_image(mountpoint)
        _output, status = execute(command("/usr/bin/hdiutil", "detach", mountpoint))
        raise "Failed to unmount #{app_name} release at #{mountpoint}" unless status == 0
      end

      def app_installed?
        @system.file_exist?(File.join(destination, "Contents", "Info.plist"))
      end
    end
  end
end
