require "test_helper"

class UpgradeBrewPackagesStepTest < Minitest::Test
  def setup
    super
    @step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
  end

  def test_depends_on_install_brew_packages
    assert_includes Dotfiles::Step::UpgradeBrewPackagesStep.depends_on, Dotfiles::Step::InstallBrewPackagesStep
  end

  def test_should_not_run_when_no_outdated_packages
    stub_brew_packages("brew \"bat\"\nbrew \"fish\"", outdated_formula: "", outdated_cask: "")
    refute @step.should_run?
  end

  def test_should_run_when_outdated_packages_exist
    stub_brew_packages("brew \"bat\"", outdated_formula: "bat", outdated_cask: "")
    assert @step.should_run?
  end

  def test_complete_when_no_outdated_packages
    stub_brew_packages("brew \"bat\"", outdated_formula: "", outdated_cask: "")
    assert @step.complete?
  end

  def test_not_complete_when_outdated_packages_exist
    stub_brew_packages("brew \"bat\"", outdated_formula: "bat", outdated_cask: "")
    refute @step.complete?
  end

  def test_complete_returns_true_when_ran
    @step.instance_variable_set(:@ran, true)
    assert @step.complete?
  end

  def test_run_upgrades_outdated_packages
    stub_brew_packages("brew \"bat\"", outdated_formula: "bat", outdated_cask: "")
    @fake_system.stub_execute_result("brew upgrade bat", ["upgraded", 0])
    @step.run
    assert @fake_system.received_operation?(:execute, "brew upgrade bat", {quiet: true})
  end

  def test_handles_cask_packages
    stub_brew_packages("cask \"firefox\"", outdated_formula: "", outdated_cask: "firefox")
    assert @step.should_run?
  end

  private

  def stub_brew_packages(brewfile_content, outdated_formula:, outdated_cask:)
    @fake_system.stub_file_content(File.join(@dotfiles_dir, "Brewfile"), brewfile_content)
    formula_packages = brewfile_content.scan(/brew "([^"]+)"/).flatten
    cask_packages = brewfile_content.scan(/cask "([^"]+)"/).flatten
    @fake_system.stub_execute_result("brew outdated --formula #{formula_packages.join(" ")} 2>/dev/null", [outdated_formula, 0])
    @fake_system.stub_execute_result("brew outdated --cask #{cask_packages.join(" ")} 2>/dev/null", [outdated_cask, 0])
  end
end
