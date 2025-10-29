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
    refute step_with(packages: ["bat", "fish"], outdated: "").should_run?
  end

  def test_should_run_when_outdated_packages_exist
    assert step_with(packages: ["bat", "fish"], outdated: "bat\nfish").should_run?
  end

  def test_complete_when_no_outdated_packages
    assert step_with(packages: ["bat"], outdated: "").complete?
  end

  def test_not_complete_when_outdated_packages_exist
    refute step_with(packages: ["bat"], outdated: "bat").complete?
  end

  private

  def step_with(packages:, outdated:)
    brewfile_content = packages.map { |pkg| "brew \"#{pkg}\"" }.join("\n")
    @fake_system.stub_file_content("/tmp/dotfiles/Brewfile", brewfile_content)
    @fake_system.stub_execute_result("HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew outdated --formula #{packages.join(" ")} 2>&1", [outdated, 0])
    create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
  end
end
