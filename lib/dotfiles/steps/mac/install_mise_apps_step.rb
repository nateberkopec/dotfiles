class Dotfiles::Step::InstallMiseAppsStep < Dotfiles::Step
  DESCRIPTION = "Installs mise-managed macOS apps into Applications.".freeze
  APPS = {"Tinycast" => "github:abue-ammar/tinycast", "CodexBar" => "github:steipete/CodexBar", "OrbStack" => "aqua:dotfiles/orbstack", "CuaDriver" => "github:trycua/cua"}.freeze

  macos_only

  def should_run?
    allowed_on_platform? && !complete?
  end

  def run
    APPS.each do |name, tool|
      destination = app_destination(name)
      unless current_app?(name, destination)
        next unless install_release(name, tool, destination)

        add_notice(title: "OrbStack setup", message: "Open OrbStack once to finish setup; it installs its CLI and keeps itself updated.") if name == "OrbStack"
        add_notice(title: "Cua Driver setup", message: "Grant CuaDriver Accessibility and Screen & System Audio Recording in System Settings, then quit and reopen it. Run cua-driver permissions status to check access.") if name == "CuaDriver"
      end
      execute(command("/usr/bin/xattr", "-dr", "com.apple.quarantine", destination))
    end
  end

  def complete?
    super
    return true unless allowed_on_platform?

    APPS.each_key do |name|
      destination = app_destination(name)
      if current_app?(name, destination)
        add_error("#{name}.app is quarantined") if quarantined?(destination)
      else
        add_error("#{name}.app is not installed in Applications")
      end
    end
    errors.empty?
  end

  private

  def install_release(name, tool, destination)
    source = app_source(name, tool)
    if source.empty?
      add_error("Mise-managed #{name} release not found")
      return false
    end
    _, status = execute(command("/usr/bin/codesign", "--verify", "--deep", "--strict", source))
    if status != 0
      add_error("Mise-managed #{name} release signature is invalid")
      return false
    end
    @system.mkdir_p(File.dirname(destination))
    @system.rm_rf(destination)
    _, status = execute(command("/usr/bin/ditto", source, destination))
    add_error("Failed to copy mise-managed #{name} release") unless status == 0
    status == 0
  end

  def app_source(name, tool)
    return "" unless command_exists?("mise")

    install_dir, status = execute(command("mise", "--cd", @home, "where", tool))
    path = File.join(install_dir.strip, "#{name}.app")
    (status == 0 && app_bundle?(path)) ? path : ""
  end

  def current_app?(name, destination)
    return false unless app_bundle?(destination)
    return true unless name == "CuaDriver"

    source = app_source(name, APPS.fetch(name))
    !source.empty? && @system.read_file(File.join(source, "Contents", "Info.plist")) == @system.read_file(File.join(destination, "Contents", "Info.plist"))
  end

  def app_bundle?(path)
    @system.file_exist?(File.join(path, "Contents", "Info.plist"))
  end

  def quarantined?(path)
    _, status = execute(command("/usr/bin/xattr", "-p", "com.apple.quarantine", path))
    status == 0
  end

  def app_destination(name)
    directory = user_has_admin_rights? ? "/Applications" : File.join(@home, "Applications")
    File.join(directory, "#{name}.app")
  end
end
