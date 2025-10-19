require "test_helper"

class InstallApplicationsStepTest < Minitest::Test
  def test_step_exists
    step = create_step(Dotfiles::Step::InstallApplicationsStep)
    assert_instance_of Dotfiles::Step::InstallApplicationsStep, step
  end
end
