require "test_helper"

class InstallOhMyFishStepTest < Minitest::Test
  def test_step_exists
    step = create_step(Dotfiles::Step::InstallOhMyFishStep)
    assert_instance_of Dotfiles::Step::InstallOhMyFishStep, step
  end
end
