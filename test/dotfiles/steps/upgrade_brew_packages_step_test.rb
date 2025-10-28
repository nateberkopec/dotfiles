require "test_helper"

class UpgradeBrewPackagesStepTest < Minitest::Test
  def test_depends_on_install_brew_packages
    deps = Dotfiles::Step::UpgradeBrewPackagesStep.depends_on
    assert_includes deps, Dotfiles::Step::InstallBrewPackagesStep
  end

  def test_step_exists
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    assert_instance_of Dotfiles::Step::UpgradeBrewPackagesStep, step
  end

  def test_should_not_run_when_no_outdated_packages
    @fake_system.stub_file_content("/tmp/dotfiles/Brewfile", "brew \"bat\"\nbrew \"fish\"")
    @fake_system.stub_execute_result("brew outdated --formula bat fish 2>/dev/null", ["", 0])

    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    refute step.should_run?
  end

  def test_should_run_when_outdated_packages_exist
    @fake_system.stub_file_content("/tmp/dotfiles/Brewfile", "brew \"bat\"\nbrew \"fish\"")
    @fake_system.stub_execute_result("brew outdated --formula bat fish 2>/dev/null", ["bat\nfish", 0])

    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    assert step.should_run?
  end

  def test_complete_when_no_outdated_packages
    @fake_system.stub_file_content("/tmp/dotfiles/Brewfile", "brew \"bat\"")
    @fake_system.stub_execute_result("brew outdated --formula bat 2>/dev/null", ["", 0])

    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    assert step.complete?
  end

  def test_not_complete_when_outdated_packages_exist
    @fake_system.stub_file_content("/tmp/dotfiles/Brewfile", "brew \"bat\"")
    @fake_system.stub_execute_result("brew outdated --formula bat 2>/dev/null", ["bat", 0])

    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    refute step.complete?
  end
end
