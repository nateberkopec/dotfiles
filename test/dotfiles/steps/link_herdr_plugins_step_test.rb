require "test_helper"

class LinkHerdrPluginsStepTest < StepTestCase
  step_class Dotfiles::Step::LinkHerdrPluginsStep

  PLUGIN = "/tmp/home/.local/share/dotfiles/herdr-plugins/session-template".freeze
  LINK = "herdr plugin link #{PLUGIN} --enabled".freeze

  def test_nothing_to_link_without_deployed_plugins
    refute_should_run
    assert_complete
  end

  def test_missing_herdr_is_skipped_with_notice
    deploy_plugin
    @fake_system.stub_command("command -v herdr >/dev/null 2>&1", "", exit_status: 1)
    refute_should_run
    assert_complete
    assert_match(/Install Herdr/, step.notices.first.fetch(:message))
  end

  def test_links_deployed_plugins_that_herdr_does_not_know
    deploy_plugin
    herdr_plugins([])
    assert_should_run
    step.run
    assert_executed(LINK)
    herdr_plugins([linked])
    assert_complete
  end

  def test_skips_plugins_that_are_already_linked_and_enabled
    deploy_plugin
    herdr_plugins([linked])
    refute_should_run
    assert_complete
    herdr_plugins([linked.merge("enabled" => false)])
    assert_should_run
  end

  def test_failed_link_reports_command_output
    deploy_plugin
    herdr_plugins([])
    @fake_system.stub_command(LINK, "TOML parse error", exit_status: 1)
    step.run
    assert_incomplete
    assert_includes step.errors.first, "TOML parse error"
  end

  private

  def deploy_plugin
    @fake_system.stub_file_content("#{PLUGIN}/herdr-plugin.toml", "id = 'dotfiles.session-template'")
  end

  def herdr_plugins(plugins)
    @fake_system.stub_command("command -v herdr >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command("herdr plugin list --json", JSON.generate({"result" => {"plugins" => plugins}}))
  end

  def linked
    {"plugin_root" => PLUGIN, "enabled" => true, "source" => {"kind" => "local"}}
  end
end
