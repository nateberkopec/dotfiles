require "test_helper"

class InstallBrewPackagesStepTest < Minitest::Test
  def test_depends_on_homebrew
    deps = Dotfiles::Step::InstallBrewPackagesStep.depends_on
    assert_includes deps, Dotfiles::Step::InstallHomebrewStep
  end

  def test_step_exists
    step = create_step(Dotfiles::Step::InstallBrewPackagesStep)
    assert_instance_of Dotfiles::Step::InstallBrewPackagesStep, step
  end
end
