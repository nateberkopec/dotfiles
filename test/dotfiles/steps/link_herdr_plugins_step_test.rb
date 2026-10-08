require "test_helper"

class LinkHerdrPluginsStepTest < StepTestCase
  step_class Dotfiles::Step::LinkHerdrPluginsStep

  def test_no_plugins_by_default
    refute_should_run
    assert_complete
  end

  def test_missing_checkout_is_skipped_with_notice
    configure_plugin
    refute_should_run
    assert_complete
    assert_match(/restore the local checkout/, step.notices.first.fetch(:message))
  end

  def test_missing_herdr_is_skipped_with_notice
    configure_plugin
    stub_manifest
    @fake_system.stub_command("command -v herdr >/dev/null 2>&1", "", exit_status: 1)
    refute_should_run
    assert_complete
    assert_match(/Install Herdr/, step.notices.first.fetch(:message))
  end

  def test_links_available_manifest_with_expanded_home
    configure_plugin
    stub_manifest
    stub_command_exists("herdr")
    assert_should_run
    step.run
    assert_executed("herdr plugin link /tmp/home/local-plugin --enabled")
    assert_complete
  end

  def test_relinks_on_each_run_to_refresh_manifest_and_enabled_state
    configure_plugin
    stub_manifest
    stub_command_exists("herdr")
    2.times do
      assert_should_run
      step.run
      assert_complete
    end
  end

  def test_failed_link_reports_command_output_and_successful_retry_clears_error
    configure_plugin
    stub_manifest
    stub_command_exists("herdr")
    @fake_system.stub_command("herdr plugin link /tmp/home/local-plugin --enabled", "invalid manifest\nmanifest details", exit_status: 1)
    step.run
    assert_incomplete
    assert_includes step.errors.first, "Failed to link Herdr plugin: ~/local-plugin\nExit status: 1\ninvalid manifest\nmanifest details\nCommand:"
    assert_includes step.errors.first, "herdr plugin link /tmp/home/local-plugin --enabled"
    @fake_system.stub_command("herdr plugin link /tmp/home/local-plugin --enabled", "", exit_status: 0)
    step.run
    assert_complete
  end

  def test_only_links_available_sources
    write_config(:herdr, "herdr_plugins" => ["~/local-plugin", "~/missing-plugin"])
    stub_manifest
    stub_command_exists("herdr")
    step.run
    assert_executed("herdr plugin link /tmp/home/local-plugin --enabled")
    refute_executed("herdr plugin link /tmp/home/missing-plugin --enabled")
    assert_complete
  end

  private

  def stub_command_exists(name)
    @fake_system.stub_command("command -v #{name} >/dev/null 2>&1", "", exit_status: 0)
  end

  def configure_plugin
    write_config(:herdr, "herdr_plugins" => ["~/local-plugin"])
  end

  def stub_manifest
    @fake_system.stub_file_content("/tmp/home/local-plugin/herdr-plugin.toml", "id = 'test.plugin'")
  end
end
