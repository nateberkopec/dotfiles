require "shellwords"

class Dotfiles::Step::ConfigureSpotlightStep < Dotfiles::Step
  DESCRIPTION = "Installs the managed Spotlight power and pause controller.".freeze

  include Dotfiles::Step::LaunchCtl
  prepend Dotfiles::Step::Sudoable

  macos_only

  def should_run?
    enabled? ? !controller_current? : controller_installed?
  end

  def run
    return uninstall_controller unless enabled?

    install_sources
    install_controller
    install_launchdaemon
  end

  def complete?
    super
    return !controller_installed? unless enabled?

    add_error("Spotlight controller source is stale") unless current_file?(controller_source_path, controller_content)
    add_error("Spotlight controller is missing or stale") unless current_file?(controller_path, controller_content)
    add_error("Spotlight LaunchDaemon is missing or stale") unless current_file?(launchdaemon_path, plist_content)
    @errors.empty?
  end

  private

  def install_sources
    @system.mkdir_p(source_dir)
    @system.write_file(controller_source_path, controller_content)
    @system.chmod(0o755, controller_source_path)
    @system.write_file(launchdaemon_source_path, plist_content)
  end

  def install_controller
    execute(command("install", "-d", "-o", "root", "-g", "wheel", "-m", "755", File.dirname(controller_path)), sudo: true)
    execute(command("install", "-d", "-o", "root", "-g", "wheel", "-m", "700", state_dir), sudo: true)
    execute(command("install", "-o", "root", "-g", "wheel", "-m", "755", controller_source_path, controller_path), sudo: true)
  end

  def install_launchdaemon
    execute(command("install", "-o", "root", "-g", "wheel", "-m", "644", launchdaemon_source_path, launchdaemon_path), sudo: true)
    load_launchdaemon(launchdaemon_path)
  end

  def uninstall_controller
    execute(shell_script("launchctl bootout system #{Shellwords.escape(launchdaemon_path)} 2>/dev/null || true; rm -f #{Shellwords.escape(launchdaemon_path)} #{Shellwords.escape(controller_path)}"), sudo: true)
    @system.rm_rf(source_dir)
  end

  def controller_current?
    current_file?(controller_source_path, controller_content) &&
      current_file?(controller_path, controller_content) &&
      current_file?(launchdaemon_path, plist_content)
  end

  def controller_installed?
    [controller_source_path, controller_path, launchdaemon_path].any? { |path| @system.file_exist?(path) }
  end

  def current_file?(path, content)
    @system.file_exist?(path) && @system.read_file(path) == content
  end

  def controller_content
    controller_template
      .sub("__VOLUMES__", shell_paths(spotlight_settings.fetch("volumes", default_volumes)))
      .sub("__EXCLUSIONS__", shell_paths(spotlight_settings.fetch("exclusions", [])))
      .sub("__STATE_DIR__", state_dir)
  end

  def controller_template
    @system.read_file(File.join(@dotfiles_dir, "files", "spotlight", "spotlight-controller.sh"))
  end

  def shell_paths(paths)
    paths.map { |path| Shellwords.escape(expand_path_with_home(path)) }.join(" ")
  end

  def plist_content
    <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key><string>#{launchdaemon_label}</string>
        <key>ProgramArguments</key>
        <array><string>#{controller_path}</string><string>reconcile</string></array>
        <key>RunAtLoad</key><true/>
        <key>StartInterval</key><integer>#{check_interval_seconds}</integer>
        <key>StandardOutPath</key><string>/var/log/dotfiles-spotlight.log</string>
        <key>StandardErrorPath</key><string>/var/log/dotfiles-spotlight.log</string>
      </dict>
      </plist>
    PLIST
  end

  def spotlight_settings
    @spotlight_settings ||= @config.fetch("spotlight_settings", {})
  end

  def enabled?
    spotlight_settings.fetch("enabled", false)
  end

  def check_interval_seconds
    value = spotlight_settings.fetch("check_interval_seconds", 60).to_i
    value.positive? ? value : 60
  end

  def default_volumes
    ["/", "/System/Volumes/Data"]
  end

  def source_dir
    File.join(@home, ".local", "share", "spotlight")
  end

  def controller_source_path
    File.join(source_dir, "spotlight-controller")
  end

  def launchdaemon_source_path
    File.join(source_dir, "com.user.spotlight-controller.plist")
  end

  def controller_path
    "/usr/local/libexec/dotfiles-spotlight-controller"
  end

  def launchdaemon_path
    "/Library/LaunchDaemons/com.user.spotlight-controller.plist"
  end

  def launchdaemon_label
    "com.user.spotlight-controller"
  end

  def state_dir
    "/var/db/dotfiles-spotlight"
  end
end
