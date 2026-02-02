require "test_helper"

class UpdateDebianStepTest < StepTestCase
  step_class Dotfiles::Step::UpdateDebianStep

  def test_should_not_run_by_default
    refute_should_run
  end

  def test_complete_by_default
    assert_complete
  end

  def test_should_run_when_release_update_available
    stub_release_update("99.99")

    assert_should_run
  end

  def test_incomplete_when_release_update_available
    stub_release_update("99.99")

    assert_incomplete
  end

  private

  def stub_release_update(version)
    @fake_system.stub_command(
      "do-release-upgrade -c",
      "New release '#{version}' available.",
      exit_status: 0
    )
  end
end
