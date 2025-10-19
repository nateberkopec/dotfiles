require "test_helper"

class ConfigureApplicationsStepTest < Minitest::Test
  def test_step_exists
    step = create_step(Dotfiles::Step::ConfigureApplicationsStep)
    assert_instance_of Dotfiles::Step::ConfigureApplicationsStep, step
  end
end
