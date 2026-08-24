class Dotfiles::Step::ConfigureSpotlightBatteryStep < Dotfiles::Step
  DESCRIPTION = "Installs a LaunchDaemon that disables Spotlight indexing while on battery power.".freeze

  include Dotfiles::Step::LaunchCtl
  prepend Dotfiles::Step::Sudoable

  macos_only

  def should_run?
    battery_mode_enabled? && !battery_toggle_current?
  end

  def run
    return unless fish_path
    install_script(script_path, script_content) unless script_current?
    install_spotlight_launchdaemon unless launchdaemon_current?
    load_launchdaemon(launchdaemon_path)
  end

  def complete?
    super
    return true unless battery_mode_enabled?

    add_error("Fish not found for Spotlight battery toggle") unless fish_path
    add_error("Spotlight battery script is missing or stale at #{script_path}") unless script_current?
    add_error("LaunchDaemon is missing or stale at #{launchdaemon_path}") unless launchdaemon_current?
    @errors.empty?
  end

  private

  def battery_toggle_current?
    script_current? && launchdaemon_current?
  end

  def script_current?
    current_file?(script_path, script_content)
  end

  def launchdaemon_current?
    current_file?(launchdaemon_path, plist_content)
  end

  def current_file?(path, content)
    @system.file_exist?(path) && @system.read_file(path) == content
  end

  def script_content
    <<~FISH
      #!#{fish_path}

      set -l volumes $argv
      if test (count $volumes) -eq 0
        exit 0
      end

      set -l power_line (/usr/bin/pmset -g batt | head -n 1)
      set -l desired
      if string match -q "*Battery Power*" -- $power_line
        set desired off
      else if string match -q "*AC Power*" -- $power_line
        set desired on
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

  def install_spotlight_launchdaemon
    @system.mkdir_p(script_dir)
    @system.write_file(launchdaemon_source_path, plist_content)
    execute(command("install", "-m", "644", launchdaemon_source_path, launchdaemon_path), sudo: true)
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

  def spotlight_settings
    @spotlight_settings ||= @config.fetch("spotlight_settings", {})
  end

  def battery_mode_enabled?
    spotlight_settings.fetch("battery_disable", false)
  end

  def battery_volumes
    normalize_volumes(spotlight_settings.fetch("battery_volumes", default_battery_volumes))
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
end
