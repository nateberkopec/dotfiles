require "test_helper"

class InstallHomebrewStepTest < StepTestCase
  step_class Dotfiles::Step::InstallHomebrewStep

  def test_should_run_when_brew_missing
    stub_brew_check(exit_status: 1)
    assert_should_run
  end

  def test_should_not_run_when_brew_present
    stub_brew_check
    refute_should_run
  end

  def test_complete_when_brew_installed
    stub_brew_check
    assert_complete
  end

  def test_incomplete_when_brew_missing
    stub_brew_check(exit_status: 1)
    assert_incomplete
  end

  private

  def stub_brew_check(exit_status: 0)
    @fake_system.stub_command("command -v brew >/dev/null 2>&1", "", exit_status: exit_status)
  end
end
