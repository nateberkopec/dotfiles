require "shellwords"

class Dotfiles::Step::ConfigureSpotlightIndexingStep < Dotfiles::Step
  prepend Dotfiles::Step::Sudoable

  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def run
    install_battery_toggle if battery_mode_enabled?
    disable_configured_volumes if disabled_volumes.any?
  end

  def complete?
    super
    return true unless spotlight_configured?

    check_battery_toggle if battery_mode_enabled?
    check_disabled_volumes

    @errors.empty?
  end

  private

  def install_battery_toggle
    return unless fish_path

    install_script unless script_installed?
    install_launchdaemon unless launchdaemon_installed?
    load_launchdaemon
  end

  def spotlight_configured?
    battery_mode_enabled? || disabled_volumes.any?
  end

  def check_battery_toggle
    add_error("Fish not found for Spotlight battery toggle") unless fish_path
    add_error("Spotlight battery script not installed at #{script_path}") unless script_installed?
    add_error("LaunchDaemon not installed at #{launchdaemon_path}") unless launchdaemon_installed?
  end

  def check_disabled_volumes
    disabled_volumes.each { |volume| check_disabled_volume(volume) }
  end

  def check_disabled_volume(volume)
    if volume_root?(volume)
      add_error("Spotlight indexing still enabled for #{volume}") unless indexing_disabled?(volume)
      return
    end

    unless @system.dir_exist?(volume)
      add_error("Spotlight exclusion directory missing: #{volume}")
      return
    end
    add_error("Spotlight exclusion file missing for #{volume}") unless metadata_never_index_exists?(volume)
  end

  def install_script
    debug "Installing Spotlight battery script to #{script_path}..."
    @system.mkdir_p(script_dir)
    @system.write_file(script_path, script_content)
    @system.chmod(0o755, script_path)
  end

  def install_launchdaemon
    debug "Installing LaunchDaemon to #{launchdaemon_path}..."
    @system.mkdir_p(script_dir)
    @system.write_file(launchdaemon_source_path, plist_content)
    execute("install -m 644 #{shell_escape(launchdaemon_source_path)} #{shell_escape(launchdaemon_path)}", sudo: true)
  end

  def load_launchdaemon
    debug "Loading LaunchDaemon..."
    execute("launchctl bootout system #{shell_escape(launchdaemon_path)} 2>/dev/null || true", sudo: true)
    execute("launchctl bootstrap system #{shell_escape(launchdaemon_path)}", sudo: true)
  end

  def disable_configured_volumes
    disabled_volumes.each do |volume|
      if volume_root?(volume)
        next if indexing_disabled?(volume)
        execute("mdutil -i off #{shell_escape(volume)}", sudo: true)
      else
        ensure_metadata_never_index(volume)
      end
    end
  end

  def indexing_disabled?(volume)
    output, status = execute("mdutil -s #{shell_escape(volume)}", quiet: true)
    return false unless status == 0
    output.downcase.include?("disabled")
  end

  def ensure_metadata_never_index(path)
    return if metadata_never_index_exists?(path)
    return unless @system.dir_exist?(path)

    @system.write_file(metadata_never_index_path(path), "")
  end

  def metadata_never_index_exists?(path)
    @system.file_exist?(metadata_never_index_path(path))
  end

  def metadata_never_index_path(path)
    File.join(path, ".metadata_never_index")
  end

  def script_content
    <<~FISH
      #!#{fish_path}

      set -l volumes $argv
      if test (count $volumes) -eq 0
        exit 0
      end

      set -l power_line (/usr/bin/pmset -g batt | head -n 1)
      if string match -q "*Battery Power*" -- $power_line
        set -l desired off
      else if string match -q "*AC Power*" -- $power_line
        set -l desired on
      else
        exit 0
      end

      for volume in $volumes
        set -l status_output (/usr/bin/mdutil -s $volume 2>/dev/null)
        set -l status_code $status
        if test $status_code -ne 0
          continue
        end

        set -l status_line (string lower -- (string join " " $status_output))
        if test $desired = "off"
          if string match -q "*indexing enabled*" -- $status_line
            /usr/bin/mdutil -i off $volume
          end
        else
          if string match -q "*disabled*" -- $status_line
            /usr/bin/mdutil -i on $volume
          end
        end
      end
    FISH
  end

  def plist_content
    <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>Label</key>
          <string>#{launchdaemon_label}</string>
          <key>ProgramArguments</key>
          <array>
      #{plist_program_arguments}
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>StartInterval</key>
          <integer>#{check_interval_seconds}</integer>
          <key>StandardOutPath</key>
          <string>/tmp/spotlight-battery.out</string>
          <key>StandardErrorPath</key>
          <string>/tmp/spotlight-battery.err</string>
      </dict>
      </plist>
    PLIST
  end

  def plist_program_arguments
    args = [fish_path, script_path, *battery_volumes]
    args.map { |arg| "        <string>#{arg}</string>" }.join("\n")
  end

  def fish_path
    find_fish_path
  end

  def script_dir
    File.join(@home, ".local", "share", "spotlight")
  end

  def script_path
    File.join(script_dir, "spotlight-battery.fish")
  end

  def launchdaemon_source_path
    File.join(script_dir, "com.user.spotlight-battery.plist")
  end

  def launchdaemon_path
    "/Library/LaunchDaemons/com.user.spotlight-battery.plist"
  end

  def launchdaemon_label
    "com.user.spotlight-battery"
  end

  def script_installed?
    @system.file_exist?(script_path)
  end

  def launchdaemon_installed?
    @system.file_exist?(launchdaemon_path)
  end

  def spotlight_settings
    @spotlight_settings ||= @config.fetch("spotlight_settings", {})
  end

  def battery_mode_enabled?
    spotlight_settings.fetch("battery_disable", false)
  end

  def battery_volumes
    normalize_volumes(spotlight_settings.fetch("battery_volumes", default_battery_volumes)) - disabled_volumes
  end

  def disabled_volumes
    normalize_volumes(spotlight_settings.fetch("disabled_volumes", []))
  end

  def check_interval_seconds
    interval = spotlight_settings.fetch("check_interval_seconds", 60).to_i
    interval.positive? ? interval : 60
  end

  def default_battery_volumes
    ["/", "/System/Volumes/Data"]
  end

  def normalize_volumes(volumes)
    Array(volumes).compact.map { |volume| expand_path_with_home(volume) }.uniq
  end

  def volume_root?(path)
    mount_point_for(path) == path
  end

  def mount_point_for(path)
    output, status = execute("df -P #{shell_escape(path)}", quiet: true)
    return nil unless status == 0
    lines = output.split("\n")
    return nil if lines.length < 2
    lines.last.split(/\s+/).last
  end

  def shell_escape(value)
    Shellwords.escape(value)
  end
end
