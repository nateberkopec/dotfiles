class Dotfiles::Step::ConfigureTimeMachineWakeStep < Dotfiles::Step
  DESCRIPTION = "Schedules the Mac to wake for its daily Time Machine backup.".freeze

  prepend Dotfiles::Step::Sudoable

  macos_only

  def should_run?
    configured? && super
  end

  def run
    execute(command("pmset", "repeat", "wakeorpoweron", "MTWRFSU", wake_time), sudo: true)
  end

  def complete?
    super
    return true unless configured?

    add_error("Daily Time Machine wake is not scheduled for #{display_wake_time}") unless wake_scheduled?
    @errors.empty?
  end

  private

  def configured?
    !wake_time.empty?
  end

  def wake_time
    time_machine_settings.fetch("wake_time", "").to_s
  end

  def time_machine_settings
    @time_machine_settings ||= @config.fetch("time_machine_settings", {})
  end

  def wake_scheduled?
    output, status = execute(command("pmset", "-g", "sched"), quiet: true)
    status == 0 && output.downcase.include?("wakepoweron at #{display_wake_time.downcase} every day")
  end

  def display_wake_time
    hour, minute = wake_time.split(":").map(&:to_i)
    period = (hour < 12) ? "AM" : "PM"
    display_hour = hour % 12
    display_hour = 12 if display_hour.zero?
    "#{display_hour}:#{format("%02d", minute)}#{period}"
  end
end
