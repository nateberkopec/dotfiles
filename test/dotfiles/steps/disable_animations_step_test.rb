require "test_helper"

class DisableAnimationsStepTest < StepTestCase
  step_class Dotfiles::Step::DisableAnimationsStep

  def setup
    super
    write_config("animations", animation_config)
  end

  def test_run_applies_animation_defaults_and_restarts_apps
    step.run

    animation_entries.each do |domain, key, value|
      assert_executed(defaults_write_command(domain, key, value))
    end
    assert_executed("killall Dock")
    assert_executed("killall Finder")
  end

  def test_complete_when_defaults_match
    stub_animation_defaults
    assert_complete
  end

  def test_incomplete_when_defaults_differ
    stub_animation_defaults(overrides: {"NSGlobalDomain" => {"NSAutomaticWindowAnimationsEnabled" => 1}})
    assert_incomplete
  end

  def test_incomplete_when_command_fails
    stub_animation_defaults(status_overrides: {["NSGlobalDomain", "NSAutomaticWindowAnimationsEnabled"] => 1})
    assert_incomplete
  end

  def test_update_writes_current_defaults_to_config
    stub_animation_defaults(overrides: test_overrides)

    step.update
    expect_config_write("animations") do |config|
      settings = config.fetch("animation_settings")
      test_overrides.each do |domain, pairs|
        pairs.each { |key, value| assert_equal value, settings.dig(domain, key) }
      end
    end
  end

  def test_update_only_reads_known_keys
    stub_animation_defaults
    step.update
    assert_defaults_read_count(animation_entries.size)
  end

  private

  def animation_config
    {"animation_settings" => animation_defaults}
  end

  def animation_defaults
    {
      "NSGlobalDomain" => {"NSAutomaticWindowAnimationsEnabled" => 0, "NSWindowResizeTime" => 0.001},
      "com.apple.dock" => {"launchanim" => 0, "autohide-time-modifier" => 0.4},
      "com.apple.finder" => {"DisableAllAnimations" => 1}
    }
  end

  def animation_entries
    @animation_entries ||= flatten_defaults_config(animation_defaults)
  end

  def test_overrides
    animation_defaults.transform_values { |settings| settings.transform_values { |v| v.is_a?(Integer) ? 1 - v : v * 2 } }
  end

  def stub_animation_defaults(overrides: {}, status_overrides: {})
    stub_defaults(animation_entries, overrides: overrides, status_overrides: status_overrides)
  end
end
