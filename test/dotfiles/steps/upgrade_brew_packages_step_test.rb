require "test_helper"

class UpgradeBrewPackagesStepTest < Minitest::Test
  def test_complete_returns_true
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    assert step.complete?
  end

  def test_adds_notice_for_outdated_packages
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    @fake_system.stub_command(brew_outdated_command, "bat\nfish\ngh\n")

    step.should_run?

    assert_brew_update_notice(step, "3 package(s)")
  end

  def test_no_notice_when_packages_up_to_date
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    @fake_system.stub_command(brew_outdated_command, "")

    step.should_run?

    assert_empty step.notices
  end

  def test_should_run_returns_false
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    @fake_system.stub_command(brew_outdated_command, "")

    refute step.should_run?
  end

  def test_no_notice_when_brew_outdated_fails
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    @fake_system.stub_command(brew_outdated_command, "Warning: Homebrew had a problem\nTry again later", exit_status: 1)

    step.should_run?

    assert_empty step.notices
  end

  def test_uses_quiet_homebrew_environment
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    @fake_system.stub_command(brew_outdated_command, "")

    step.should_run?

    assert @fake_system.received_operation?(:execute, brew_outdated_command, {quiet: true})
  end

  private

  def assert_brew_update_notice(step, count_message)
    assert_equal 1, step.notices.size
    notice = step.notices.first
    assert_includes notice[:title], "Homebrew Updates Available"
    assert_includes notice[:message], count_message
    assert_includes notice[:message], "brew upgrade"
  end

  def brew_outdated_command
    [{"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", "outdated", "--quiet"]
  end
end
