require "test_helper"

class InstallHomebrewStepTest < StepTestCase
  step_class Dotfiles::Step::InstallHomebrewStep

  def test_should_run_when_brew_missing
    stub_admin
    stub_brew_check(exit_status: 1)
    assert_should_run
  end

  def test_should_not_run_when_brew_present_for_admin
    stub_admin
    stub_brew_check
    refute_should_run
  end

  def test_should_run_for_non_admin_without_private_homebrew
    stub_non_admin
    stub_brew_check

    assert_should_run
  end

  def test_should_not_run_for_non_admin_with_private_homebrew
    stub_non_admin
    @fake_system.stub_file_content(private_brew_bin, "brew")

    refute_should_run
  end

  def test_complete_when_brew_installed_for_admin
    stub_admin
    stub_brew_check
    assert_complete
  end

  def test_complete_when_private_homebrew_installed_for_non_admin
    stub_non_admin
    @fake_system.stub_file_content(private_brew_bin, "brew")

    assert_complete
  end

  def test_incomplete_when_brew_missing
    stub_admin
    stub_brew_check(exit_status: 1)
    assert_incomplete
  end

  def test_run_installs_private_homebrew_for_non_admin
    stub_non_admin

    step.run

    assert_executed("git clone --depth=1 https://github.com/Homebrew/brew '#{private_brew_prefix}'")
    assert_executed("mkdir -p '#{private_brew_prefix}/Cellar' '#{private_brew_prefix}/Caskroom' '#{@home}/Library/Caches/Homebrew'")
  end

  private

  def stub_brew_check(exit_status: 0)
    @fake_system.stub_command("command -v brew >/dev/null 2>&1", "", exit_status: exit_status)
  end

  def stub_admin
    @fake_system.stub_command("groups", "admin staff")
  end

  def stub_non_admin
    @fake_system.stub_command("groups", "staff")
  end

  def private_brew_prefix
    File.join(@home, ".homebrew")
  end

  def private_brew_bin
    File.join(private_brew_prefix, "bin", "brew")
  end
end
