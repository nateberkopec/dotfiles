require "test_helper"

class UpdateDebianPackagesStepTest < StepTestCase
  step_class Dotfiles::Step::UpdateDebianPackagesStep

  def test_should_run_by_default
    assert_should_run
  end

  def test_should_not_run_when_apt_missing
    @fake_system.stub_command("command -v apt-get >/dev/null 2>&1", "", exit_status: 1)

    refute_should_run
  end

  def test_complete_by_default
    assert_complete
  end
end
