require "test_helper"

class ConfigureTimeMachineStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureTimeMachineStep

  def test_run_applies_time_machine_settings_and_exclusions
    write_time_machine_config

    step.run

    assert_executed(["sudo", "defaults", "write", time_machine_domain, "AutoBackup", "-bool", "true"], quiet: false)
    assert_executed(["sudo", "defaults", "write", time_machine_domain, "AutoBackupInterval", "-int", "86400"], quiet: false)
    assert_executed(["sudo", "defaults", "write", time_machine_domain, "RequiresACPower", "-bool", "false"], quiet: false)
    assert_executed(["sudo", "tmutil", "addexclusion", "-p", *expanded_exclusions], quiet: false)
  end

  def test_run_expands_tilde_in_exclusions
    write_time_machine_config("exclusions" => ["~/Library/pnpm"])

    step.run

    assert_executed(["sudo", "tmutil", "addexclusion", "-p", File.join(@home, "Library", "pnpm")], quiet: false)
  end

  def test_complete_when_settings_match_and_exclusions_are_fixed_paths
    write_time_machine_config
    stub_time_machine_defaults

    assert_complete
  end

  def test_complete_when_no_time_machine_config
    write_config("time_machine", "time_machine_settings" => {})

    assert_complete
  end

  def test_incomplete_when_bool_setting_differs
    write_time_machine_config
    stub_time_machine_defaults(overrides: {"AutoBackup" => "0"})

    assert_incomplete
  end

  def test_incomplete_when_interval_differs
    write_time_machine_config
    stub_time_machine_defaults(overrides: {"AutoBackupInterval" => "3600"})

    assert_incomplete
  end

  def test_incomplete_when_exclusion_missing
    write_time_machine_config
    stub_time_machine_defaults(skip_paths: [expanded_exclusions.first])

    assert_incomplete
  end

  private

  def write_time_machine_config(overrides = {})
    settings = {
      "auto_backup" => true,
      "auto_backup_interval_seconds" => 86_400,
      "requires_ac_power" => false,
      "exclusions" => exclusions
    }.merge(overrides)
    write_config("time_machine", "time_machine_settings" => settings)
  end

  def stub_time_machine_defaults(overrides: {}, skip_paths: expanded_exclusions)
    defaults = {
      "AutoBackup" => "1",
      "AutoBackupInterval" => "86400",
      "RequiresACPower" => "0",
      "SkipPaths" => defaults_array(skip_paths)
    }.merge(overrides)

    defaults.each do |key, value|
      @fake_system.stub_command(["defaults", "read", time_machine_domain, key], value, 0)
    end
  end

  def defaults_array(values)
    lines = values.map { |value| "    #{value}" }
    "(\n#{lines.join("\n")}\n)"
  end

  def exclusions
    [
      "~/.cache/huggingface",
      "~/Library/Application Support/com.apple.wallpaper/aerials/videos",
      "~/.npm"
    ]
  end

  def expanded_exclusions
    [
      File.join(@home, ".cache", "huggingface"),
      File.join(@home, "Library", "Application Support", "com.apple.wallpaper", "aerials", "videos"),
      File.join(@home, ".npm")
    ]
  end

  def time_machine_domain
    "/Library/Preferences/com.apple.TimeMachine"
  end
end
