require "test_helper"

class VSCodeConfigurationStepTest < Minitest::Test
  def test_depends_on_correct_steps
    deps = Dotfiles::Step::VSCodeConfigurationStep.depends_on
    assert_includes deps, Dotfiles::Step::InstallApplicationsStep
  end

  def test_not_complete_without_files
    ENV["CI"] = "true"

    step = create_step(Dotfiles::Step::VSCodeConfigurationStep)
    refute step.complete?
  ensure
    ENV.delete("CI")
  end

  def test_display_name
    assert_equal "VS Code Configuration", Dotfiles::Step::VSCodeConfigurationStep.display_name
  end
end
