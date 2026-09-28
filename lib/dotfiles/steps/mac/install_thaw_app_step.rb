class Dotfiles::Step::InstallThawAppStep < Dotfiles::Step
  DESCRIPTION = "Installs the mise-managed Thaw release into Applications.".freeze
  THAW_TOOL = "github:thaw-app/Thaw".freeze

  macos_only

  def should_run?
    allowed_on_platform? && !complete?
  end

  def run
    source = thaw_source
    return add_error("Mise-managed Thaw release not found") if source.empty?

    install_app(source) unless app_installed?
  end

  def complete?
    super
    return true unless allowed_on_platform?

    add_error("Thaw.app is not installed in Applications") unless app_installed?
    errors.empty?
  end

  private

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
    @system.mkdir_p(File.dirname(destination))
    _output, status = execute(command("/usr/bin/ditto", File.join(mountpoint, "Thaw.app"), destination))
    raise "Failed to copy Thaw release" unless status == 0
  end

  def unmount_image(mountpoint)
    _output, status = execute(command("/usr/bin/hdiutil", "detach", mountpoint))
    raise "Failed to unmount Thaw release at #{mountpoint}" unless status == 0
  end

  def thaw_source
    return @thaw_source if defined?(@thaw_source)
    return @thaw_source = "" unless command_exists?("mise")

    install_dir, status = execute(command("mise", "--cd", @home, "where", THAW_TOOL))
    path = File.join(install_dir.strip, "Thaw.dmg")
    @thaw_source = (status == 0 && @system.file_exist?(path)) ? path : ""
  end

  def app_installed?
    @system.file_exist?(File.join(destination, "Contents", "Info.plist"))
  end

  def destination
    @destination ||= File.join(applications_directory, "Thaw.app")
  end

  def applications_directory
    user_has_admin_rights? ? "/Applications" : File.join(@home, "Applications")
  end
end
