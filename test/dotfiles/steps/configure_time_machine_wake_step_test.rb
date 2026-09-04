require "test_helper"

class ConfigureTimeMachineWakeStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureTimeMachineWakeStep

  def test_should_run_when_daily_wake_is_missing
    write_wake_config
    stub_schedule("No repeating power events scheduled")
    @fake_system.stub_macos

    assert_should_run
  end

  def test_run_schedules_daily_wake
    write_wake_config

    step.run

    assert_executed(["sudo", "pmset", "repeat", "wakeorpoweron", "MTWRFSU", "05:15:00"], quiet: false)
  end

  def test_complete_when_daily_wake_matches
    write_wake_config
    stub_schedule("wakepoweron at 5:15AM every day")

    assert_complete
  end

  def test_incomplete_when_daily_wake_differs
    write_wake_config
    stub_schedule("wakepoweron at 6:00AM every day")

    assert_incomplete
  end

  def test_complete_without_wake_time
    write_config("time_machine_wake", "time_machine_settings" => {})

    assert_complete
  end

  private

  def write_wake_config
    write_config("time_machine_wake", "time_machine_settings" => {"wake_time" => "05:15:00"})
  end

  def stub_schedule(schedule)
    @fake_system.stub_command(["pmset", "-g", "sched"], "Repeating power events:\n  #{schedule}\n", 0)
  end
end
