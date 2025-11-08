require "test_helper"

class UpgradeBrewPackagesStepTest < Minitest::Test
  def test_complete_returns_true
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    assert step.complete?
  end

  def test_adds_notice_for_outdated_packages
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    @fake_system.stub_command("brew outdated", "bat\nfish\ngh")

    step.should_run?

    assert_equal 1, step.notices.size
    assert_includes step.notices.first[:title], "Homebrew Updates Available"
    assert_includes step.notices.first[:message], "3 package(s)"
    assert_includes step.notices.first[:message], "brew upgrade"
  end

  def test_no_notice_when_packages_up_to_date
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    @fake_system.stub_command("brew outdated", "")

    step.should_run?

    assert_empty step.notices
  end

  def test_should_run_returns_false
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    @fake_system.stub_command("brew outdated", "")

    refute step.should_run?
  end
end
