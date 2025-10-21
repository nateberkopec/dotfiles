require "test_helper"

class ConfigureFishStepTest < Minitest::Test
  def test_depends_on_correct_steps
    deps = Dotfiles::Step::ConfigureFishStep.depends_on
    assert_includes deps, Dotfiles::Step::InstallBrewPackagesStep
  end
end
