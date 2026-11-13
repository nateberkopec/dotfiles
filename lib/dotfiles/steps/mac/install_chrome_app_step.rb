class Dotfiles::Step::InstallChromeAppStep < Dotfiles::Step
  DESCRIPTION = "Installs Google Chrome from Google's signed release; Chrome updates itself afterward.".freeze
  URL = "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg".freeze
  REQUIREMENT = 'anchor apple generic and certificate leaf[subject.OU] = "EQHXZ8M8AV"'.freeze

  macos_only

  def should_run?
    !ENV["CI"] && allowed_on_platform? && !complete?
  end

  def run
    return if ENV["CI"]
    return unless allowed_on_platform?
    return if app_installed?

    image = temp_path("chrome-release.dmg")
    _output, status = execute(command("curl", "-fsSL", "--retry", "2", "-o", image, URL))
    raise "Failed to download Google Chrome" unless status == 0

    install_app(image)
    add_notice(title: "Google Chrome setup", message: "Open Google Chrome to sign in and choose it as your default browser.")
  ensure
    @system.rm_rf(image) if image
  end

  def complete?
    super
    return true if ENV["CI"] || !allowed_on_platform?

    add_error("Google Chrome.app is not installed in Applications") unless app_installed?
    errors.empty?
  end

  private

  def install_app(image)
    mountpoint = temp_path("chrome-mount")
    @mounted = false
    @system.mkdir_p(mountpoint)
    _output, status = execute(command("/usr/bin/hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", mountpoint, image))
    raise "Failed to mount Google Chrome image" unless status == 0

    @mounted = true
    copy_app(File.join(mountpoint, "Google Chrome.app"))
  ensure
    if @mounted
      _output, status = execute(command("/usr/bin/hdiutil", "detach", mountpoint))
      raise "Failed to unmount Google Chrome image at #{mountpoint}" unless status == 0
    end
    @system.rm_rf(mountpoint) if mountpoint
  end

  def copy_app(source)
    _output, status = execute(command("/usr/bin/codesign", "--verify", "--deep", "-R=#{REQUIREMENT}", source))
    raise "Google Chrome signature is invalid" unless status == 0

    @system.mkdir_p(File.dirname(destination))
    _output, status = execute(command("/usr/bin/ditto", source, destination))
    raise "Failed to copy Google Chrome" unless status == 0
  end

  def app_installed?
    @system.file_exist?(File.join(destination, "Contents", "Info.plist"))
  end

  def destination
    directory = user_has_admin_rights? ? "/Applications" : File.join(@home, "Applications")
    File.join(directory, "Google Chrome.app")
  end
end
