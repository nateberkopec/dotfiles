require "test_helper"

class InstallStarshipProfilesStepTest < StepTestCase
  step_class Dotfiles::Step::InstallStarshipProfilesStep

  def setup
    super
    stub_starship_profiles_not_installed
  end

  def test_should_run_when_not_installed
    assert_should_run
  end

  def test_should_run_when_installed_but_no_config
    stub_starship_profiles_installed
    assert_should_run
  end

  def test_should_not_run_when_installed_and_configured
    stub_starship_profiles_installed
    stub_profiles_config_exists
    refute_should_run
  end

  def test_run_checks_pr_status_first
    stub_pr_open
    step.run

    assert_executed("gh pr view https://github.com/starship/starship/pull/6894 --json state -q .state")
  end

  def test_run_raises_when_pr_merged
    stub_pr_merged
    error = assert_raises(RuntimeError) { step.run }
    assert_match(/PR.*is now merged/, error.message)
    assert_match(/native multi-config support/, error.message)
  end

  def test_run_raises_when_pr_closed
    stub_pr_closed
    error = assert_raises(RuntimeError) { step.run }
    assert_match(/PR.*is now closed/, error.message)
  end

  def test_run_continues_when_gh_fails
    @fake_system.stub_command(
      "gh pr view https://github.com/starship/starship/pull/6894 --json state -q .state",
      "", 1
    )
    step.run
    assert_executed("cargo install starship-profiles", quiet: false)
  end

  def test_run_installs_starship_profiles
    stub_pr_open
    step.run

    assert_executed("cargo install starship-profiles", quiet: false)
  end

  def test_run_skips_install_when_already_installed
    stub_starship_profiles_installed
    stub_pr_open
    step.run

    refute_executed("cargo install starship-profiles", quiet: false)
  end

  def test_run_creates_profiles_directory
    stub_pr_open
    step.run

    assert_command_run(:mkdir_p, profiles_dir)
  end

  def test_run_creates_profiles_toml
    stub_pr_open
    step.run

    assert @fake_system.file_exist?(profiles_toml_path)
  end

  def test_run_creates_default_profile
    stub_pr_open
    step.run

    assert @fake_system.file_exist?(default_profile_path)
  end

  def test_complete_when_installed_and_configured
    stub_starship_profiles_installed
    stub_profiles_config_exists
    assert_complete
  end

  def test_incomplete_when_not_installed
    stub_profiles_config_exists
    assert_incomplete
  end

  def test_incomplete_when_no_config
    stub_starship_profiles_installed
    assert_incomplete
  end

  private

  def stub_starship_profiles_not_installed
    @fake_system.stub_command("command -v starship-profiles", "", 1)
  end

  def stub_starship_profiles_installed
    @fake_system.stub_command("command -v starship-profiles", "/usr/local/bin/starship-profiles", 0)
  end

  def stub_profiles_config_exists
    @fake_system.write_file(profiles_toml_path, "# config")
  end

  def stub_pr_open
    @fake_system.stub_command(
      "gh pr view https://github.com/starship/starship/pull/6894 --json state -q .state",
      "OPEN", 0
    )
  end

  def stub_pr_merged
    @fake_system.stub_command(
      "gh pr view https://github.com/starship/starship/pull/6894 --json state -q .state",
      "MERGED", 0
    )
  end

  def stub_pr_closed
    @fake_system.stub_command(
      "gh pr view https://github.com/starship/starship/pull/6894 --json state -q .state",
      "CLOSED", 0
    )
  end

  def profiles_dir
    File.join(@home, ".config/starship/profiles")
  end

  def profiles_toml_path
    File.join(@home, ".config/starship/profiles.toml")
  end

  def default_profile_path
    File.join(profiles_dir, "default.toml")
  end
end
