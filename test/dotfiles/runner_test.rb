require "test_helper"

class RunnerTest < Minitest::Test
  def test_runner_initialization
    runner = Dotfiles::Runner.new

    assert_instance_of Dotfiles::Runner, runner
  end

  def test_runner_can_be_created
    runner = Dotfiles::Runner.new

    assert_respond_to runner, :run
  end
end
