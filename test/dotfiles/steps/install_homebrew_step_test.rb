require "test_helper"

class InstallHomebrewStepTest < Minitest::Test
  def test_should_run_when_brew_not_installed
    @fake_system.stub_command_output("command -v brew >/dev/null 2>&1", "", exit_status: 1)

    step = create_step(Dotfiles::Step::InstallHomebrewStep)
    assert step.should_run?
  end

  def test_should_not_run_when_brew_installed
    @fake_system.stub_command_output("command -v brew >/dev/null 2>&1", "", exit_status: 0)

    step = create_step(Dotfiles::Step::InstallHomebrewStep)
    refute step.should_run?
  end

  def test_step_exists
    step = create_step(Dotfiles::Step::InstallHomebrewStep)
    assert_instance_of Dotfiles::Step::InstallHomebrewStep, step
  end

  def test_complete_when_brew_exists
    @fake_system.stub_command_output("command -v brew >/dev/null 2>&1", "", exit_status: 0)

    step = create_step(Dotfiles::Step::InstallHomebrewStep)
    assert step.complete?
  end

  def test_incomplete_when_brew_missing
    @fake_system.stub_command_output("command -v brew >/dev/null 2>&1", "", exit_status: 1)

    step = create_step(Dotfiles::Step::InstallHomebrewStep)
    refute step.complete?
  end
end
