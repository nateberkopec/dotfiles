class Dotfiles::Step::InstallTinycastAppStep < Dotfiles::Step
  DESCRIPTION = "Installs the mise-managed Tinycast release into Applications.".freeze
  TINYCAST_TOOL = "github:abue-ammar/tinycast".freeze

  macos_only

  def should_run?
    allowed_on_platform? && !complete?
  end

  def run
    source = tinycast_source
    return add_error("Mise-managed Tinycast release not found") if source.empty?

    install_app(source) unless app_installed?
    clear_quarantine
  end

  def complete?
    super
    return true unless allowed_on_platform?

    add_error("Tinycast.app is not installed in Applications") unless app_installed?
    add_error("Tinycast.app is quarantined") if app_installed? && quarantined?
    errors.empty?
  end

  private

  def install_app(source)
    @system.mkdir_p(File.dirname(destination))
    @system.rm_rf(destination)
    execute(command("/usr/bin/ditto", source, destination))
  end

  def clear_quarantine
    execute(command("/usr/bin/xattr", "-dr", "com.apple.quarantine", destination))
  end

  def tinycast_source
    return @tinycast_source if defined?(@tinycast_source)
    return @tinycast_source = "" unless command_exists?("mise")

    install_dir, status = execute(command("mise", "--cd", @home, "where", TINYCAST_TOOL))
    path = File.join(install_dir.strip, "Tinycast.app")
    @tinycast_source = (status == 0 && app_bundle?(path)) ? path : ""
  end

  def app_installed?
    app_bundle?(destination)
  end

  def app_bundle?(path)
    @system.file_exist?(File.join(path, "Contents", "Info.plist"))
  end

  def quarantined?
    _, status = execute(command("/usr/bin/xattr", "-p", "com.apple.quarantine", destination))
    status == 0
  end

  def destination
    @destination ||= File.join(applications_directory, "Tinycast.app")
  end

  def applications_directory
    user_has_admin_rights? ? "/Applications" : File.join(@home, "Applications")
  end
end
