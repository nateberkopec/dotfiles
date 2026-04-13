require "rbconfig"
require "shellwords"
require "test_helper"

class SyncAgentLinksStepTest < StepTestCase
  step_class Dotfiles::Step::SyncAgentLinksStep

  def setup
    super
    write_config("config", "dotagents_clients" => %w[claude codex])
    @fake_system.mkdir_p(File.join(@home, ".agents"))
  end

  def test_should_run_when_agents_root_and_mise_are_available
    assert_should_run
  end

  def test_run_executes_dotagents_driver
    step.run

    assert_executed!(expected_command, quiet: false)
  end

  def test_complete_when_agents_root_exists
    assert_complete
  end

  def test_incomplete_without_agents_root
    @fake_system.rm_rf(File.join(@home, ".agents"))

    assert_incomplete
    assert_includes step.errors, "Missing ~/.agents; sync home directory first"
  end

  def test_complete_when_no_clients_configured
    write_config("config", "dotagents_clients" => [])
    current_step = rebuild_step!

    refute_should_run(current_step)
    assert_complete(current_step)
  end

  private

  def expected_command
    [
      Shellwords.shellescape(RbConfig.ruby),
      Shellwords.shellescape(File.join(@dotfiles_dir, "tools", "drive_dotagents.rb")),
      "--home", Shellwords.shellescape(@home),
      "--clients", Shellwords.shellescape("claude,codex"),
      "--dotagents-command",
      Shellwords.shellescape("mise --cd #{Shellwords.shellescape(@dotfiles_dir)} exec npm:@iannuttall/dotagents -- dotagents")
    ].join(" ")
  end
end
