require "test_helper"

class ConfigureIceStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureIceStep

  def setup
    super
    configure_paths
  end

  def test_should_run_when_installed_and_incomplete
    install_ice
    assert_should_run
  end

  def test_should_not_run_when_not_installed
    refute_should_run
  end

  def test_run_copies_preferences_and_configures_login
    install_ice
    stub_config_files

    step.run

    assert_command_run(:cp, ice_config_path, ice_preferences_path)
    assert_executed(login_items_creation_command)
    assert_executed("killall Ice 2>/dev/null; open -a Ice")
  end

  def test_complete_when_preferences_and_login_item_exist
    stub_ice_configured
    assert_complete
  end

  def test_incomplete_without_preferences
    stub_login_items("Ice")
    assert_incomplete
  end

  def test_incomplete_without_login_item
    stub_preferences
    stub_login_items("")
    assert_incomplete
  end

  def test_ci_env_skips_configuration
    with_ci do
      install_ice
      refute_should_run
      assert_complete
    end
  end

  def test_update_copies_preferences_into_repo
    stub_preferences("plist data")
    step.update
    assert_command_run(:cp, ice_preferences_path, ice_config_path)
  end

  def test_update_skips_when_preferences_missing
    step.update
    refute_command_run(:cp)
  end

  private

  def step_overrides
    {dotfiles_dir: @dotfiles_dir}
  end

  def configure_paths
    paths = {
      "application_paths" => {"ice_preferences" => ice_preferences_path},
      "dotfiles_sources" => {"ice_config" => "files/ice/com.jordanbaird.Ice.plist"}
    }
    step.config.paths = paths
  end

  def ice_preferences_path
    File.join(@home, "Library/Preferences/com.jordanbaird.Ice.plist")
  end

  def ice_config_path
    File.join(@dotfiles_dir, "files/ice/com.jordanbaird.Ice.plist")
  end

  def install_ice
    @fake_system.stub_file_content("/Applications/Ice.app", "app")
  end

  def stub_preferences(content = "plist")
    @fake_system.stub_file_content(ice_preferences_path, content)
  end

  def stub_login_items(output, status: 0)
    @fake_system.stub_command(login_items_list_command, output, exit_status: status)
  end

  def stub_config_files
    @fake_system.stub_file_content(ice_config_path, "plist template")
  end

  def stub_ice_configured
    stub_preferences
    stub_login_items("Ice,AnotherApp")
  end

  def login_items_list_command
    "osascript -e 'tell application \"System Events\" to get the name of every login item'"
  end

  def login_items_creation_command
    "osascript -e 'tell application \"System Events\" to make login item at end with properties {path:\"/Applications/Ice.app\", hidden:false}'"
  end
end
