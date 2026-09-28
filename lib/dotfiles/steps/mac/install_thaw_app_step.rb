class Dotfiles::Step::InstallThawAppStep < Dotfiles::Step
  DESCRIPTION = "Installs the pinned Thaw release on admin macOS machines.".freeze
  VERSION = "2.0.1".freeze
  SHA256 = "5e4a17c39075a9d27b0c9c31619cee875880befa79021d8ddc9ae6d90e345cbf".freeze
  URL = "https://github.com/thaw-app/Thaw/releases/download/#{VERSION}/Thaw.dmg".freeze

  macos_only

  def should_run?
    !ENV["CI"] && allowed_on_platform? && user_has_admin_rights? && !complete?
  end

  def run
    return if ENV["CI"]
    return unless allowed_on_platform? && user_has_admin_rights?
    return if app_installed?

    image = temp_path("thaw-release.dmg")
    download_image(image)
    install_app(image)
    add_notice(title: "Thaw setup", message: "Open Thaw, grant Accessibility, and choose your layout and launch-at-login settings. Thaw keeps your profiles and preferences locally.")
  ensure
    @system.rm_rf(image) if image
  end

  def complete?
    super
    return true if ENV["CI"] || !allowed_on_platform? || !user_has_admin_rights?

    add_error("Thaw.app is not installed in Applications") unless app_installed?
    errors.empty?
  end

  private

  def download_image(image)
    _output, status = execute(command("curl", "-fsSL", "--retry", "2", "-o", image, URL))
    raise "Failed to download Thaw release" unless status == 0

    output, status = execute(command("/usr/bin/shasum", "-a", "256", image))
    raise "Thaw release checksum mismatch" unless status == 0 && output.split.first == SHA256
  end

  def install_app(image)
    mountpoint = temp_path("thaw-mount")
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
    raise "Failed to mount Thaw release" unless status == 0
    @mounted = true
  end

  def copy_app(mountpoint)
    source = File.join(mountpoint, "Thaw.app")
    _output, status = execute(command("/usr/bin/codesign", "--verify", "--deep", "--strict", source))
    raise "Thaw release signature is invalid" unless status == 0

    _output, status = execute(command("/usr/bin/ditto", source, destination))
    raise "Failed to copy Thaw release" unless status == 0
  end

  def unmount_image(mountpoint)
    _output, status = execute(command("/usr/bin/hdiutil", "detach", mountpoint))
    raise "Failed to unmount Thaw release at #{mountpoint}" unless status == 0
  end

  def app_installed?
    @system.file_exist?(File.join(destination, "Contents", "Info.plist"))
  end

  def destination
    "/Applications/Thaw.app"
  end
end
