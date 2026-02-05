require "shellwords"

class Dotfiles::Step::ConfigureSpotlightBatteryStep < Dotfiles::Step
  include Dotfiles::Step::LaunchCtl
  prepend Dotfiles::Step::Sudoable

  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def should_run?
    battery_mode_enabled? && !battery_toggle_installed?
  end

  def run
    return unless fish_path
    install_script(script_path, script_content) unless script_installed?(script_path)
    install_spotlight_launchdaemon unless plist_installed?(launchdaemon_path)
    load_launchdaemon(launchdaemon_path)
  end

  def complete?
    super
    return true unless battery_mode_enabled?

    add_error("Fish not found for Spotlight battery toggle") unless fish_path
    add_error("Spotlight battery script not installed at #{script_path}") unless script_installed?(script_path)
    add_error("LaunchDaemon not installed at #{launchdaemon_path}") unless plist_installed?(launchdaemon_path)
    @errors.empty?
  end

  private

  def battery_toggle_installed?
    script_installed?(script_path) && plist_installed?(launchdaemon_path)
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

  def install_spotlight_launchdaemon
    @system.mkdir_p(script_dir)
    @system.write_file(launchdaemon_source_path, plist_content)
    execute("install -m 644 #{Shellwords.escape(launchdaemon_source_path)} #{Shellwords.escape(launchdaemon_path)}", sudo: true)
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
    disabled = normalize_volumes(spotlight_settings.fetch("disabled_volumes", []))
    normalize_volumes(spotlight_settings.fetch("battery_volumes", default_battery_volumes)) - disabled
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
