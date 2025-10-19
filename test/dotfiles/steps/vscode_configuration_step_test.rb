require "test_helper"

class VSCodeConfigurationStepTest < Minitest::Test
  def test_depends_on_correct_steps
    deps = Dotfiles::Step::VSCodeConfigurationStep.depends_on
    assert_includes deps, Dotfiles::Step::InstallApplicationsStep
    assert_includes deps, Dotfiles::Step::CloneDotfilesStep
  end

  def test_complete_in_ci
    ENV["CI"] = "true"

    step = create_step(Dotfiles::Step::VSCodeConfigurationStep)
    assert step.complete?
  ensure
    ENV.delete("CI")
  end

  def test_display_name
    assert_equal "VS Code Configuration", Dotfiles::Step::VSCodeConfigurationStep.display_name
  end
end
