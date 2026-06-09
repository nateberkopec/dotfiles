class Dotfiles::Step::ConfigureTimeMachineStep < Dotfiles::Step
  DESCRIPTION = "Configures Time Machine backup settings and fixed-path exclusions.".freeze

  prepend Dotfiles::Step::Sudoable

  macos_only

  def should_run?
    configured? && super
  end

  def run
    write_bool("AutoBackup", auto_backup?)
    write_int("AutoBackupInterval", auto_backup_interval_seconds)
    write_bool("RequiresACPower", requires_ac_power?)
    add_exclusions
  end

  def complete?
    super
    return true unless configured?

    check_bool("AutoBackup", auto_backup?)
    check_int("AutoBackupInterval", auto_backup_interval_seconds)
    check_bool("RequiresACPower", requires_ac_power?)
    check_exclusions
    @errors.empty?
  end

  private

  DEFAULT_INTERVAL_SECONDS = 86_400
  TIME_MACHINE_DOMAIN = "/Library/Preferences/com.apple.TimeMachine".freeze

  def configured?
    time_machine_settings.any?
  end

  def time_machine_settings
    @time_machine_settings ||= @config.fetch("time_machine_settings", {})
  end

  def auto_backup?
    time_machine_settings.fetch("auto_backup", true)
  end

  def auto_backup_interval_seconds
    interval = time_machine_settings.fetch("auto_backup_interval_seconds", DEFAULT_INTERVAL_SECONDS).to_i
    interval.positive? ? interval : DEFAULT_INTERVAL_SECONDS
  end

  def requires_ac_power?
    time_machine_settings.fetch("requires_ac_power", false)
  end

  def desired_exclusions
    @desired_exclusions ||= Array(time_machine_settings.fetch("exclusions", [])).compact.map { |path| expand_path_with_home(path) }.uniq
  end

  def write_bool(key, value)
    execute(command("defaults", "write", TIME_MACHINE_DOMAIN, key, "-bool", defaults_bool(value)), sudo: true)
  end

  def write_int(key, value)
    execute(command("defaults", "write", TIME_MACHINE_DOMAIN, key, "-int", value.to_s), sudo: true)
  end

  def add_exclusions
    return unless desired_exclusions.any?
    execute(command("tmutil", "addexclusion", "-p", *desired_exclusions), sudo: true)
  end

  def check_bool(key, value)
    add_error("Time Machine setting #{key} not set to #{value}") unless defaults_read(key) == read_bool(value)
  end

  def check_int(key, value)
    add_error("Time Machine setting #{key} not set to #{value}") unless defaults_read(key) == value.to_s
  end

  def check_exclusions
    desired_exclusions.each do |path|
      add_error("Time Machine fixed-path exclusion missing: #{collapse_path_to_home(path)}") unless fixed_path_excluded?(path)
    end
  end

  def defaults_read(key)
    output, status = execute(command("defaults", "read", TIME_MACHINE_DOMAIN, key), quiet: true)
    return nil unless status == 0
    output.strip
  end

  def fixed_path_excluded?(path)
    skip_paths.include?(path)
  end

  def skip_paths
    @skip_paths ||= defaults_read("SkipPaths").to_s
  end

  def defaults_bool(value)
    value ? "true" : "false"
  end

  def read_bool(value)
    value ? "1" : "0"
  end
end
