require "test_helper"

class InstallTryStepTest < StepTestCase
  step_class Dotfiles::Step::InstallTryStep

  def test_should_run_when_try_not_installed
    assert_should_run
  end

  def test_should_not_run_when_try_exists
    @fake_system.write_file(try_path, "")
    refute_should_run
  end

  def test_run_creates_directory_and_downloads
    step.run

    assert_command_run(:mkdir_p, File.dirname(try_path))
    assert_executed("curl -sL https://raw.githubusercontent.com/tobi/try/refs/heads/main/try.rb -o #{try_path}")
    assert_command_run(:chmod, 0o755, try_path)
  end

  def test_complete_when_file_exists
    @fake_system.write_file(try_path, "")
    assert_complete
  end

  def test_incomplete_when_file_missing
    assert_incomplete
  end

  private

  def try_path
    File.join(@home, "Documents/Code.nosync/upstream/try/try.rb")
  end
end
