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

  def test_run_executes_dotagents_via_script
    step.run

    assert_executed!(expected_command, quiet: false)
  end

  def test_run_uses_bsd_script_on_macos
    @fake_system.stub_macos

    step.run

    assert_executed!(expected_command(macos: true), quiet: false)
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

  def expected_command(macos: false)
    "printf '%b' #{Shellwords.shellescape(dotagents_input)} | #{script_command(macos: macos)}"
  end

  def script_command(macos: false)
    command = "HOME=#{Shellwords.shellescape(@home)} mise --cd #{Shellwords.shellescape(@dotfiles_dir)} exec npm:@iannuttall/dotagents -- dotagents"

    if macos
      "script -q /dev/null sh -lc #{Shellwords.shellescape(command)}"
    else
      "script -qefc #{Shellwords.shellescape(command)} /dev/null"
    end
  end

  def dotagents_input
    ["\\r", "a", client_selection_input, "\\r\\r\\r", "\\e[B\\e[B\\e[B\\r"].join
  end

  def client_selection_input
    %w[claude factory codex cursor opencode gemini github ampcode].map.with_index do |client, index|
      selection = %w[claude codex].include?(client) ? " " : nil
      down = (index == 7) ? nil : "\\e[B"
      [selection, down].join
    end.join
  end
end
