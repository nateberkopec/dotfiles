require "test_helper"

class ConfigureIceStepTest < Minitest::Test
  def setup
    super
    @step = create_step(Dotfiles::Step::ConfigureIceStep)
    @step.config.paths = {
      "application_paths" => {
        "ice_preferences" => "#{@home}/Library/Preferences/com.jordanbaird.Ice.plist"
      },
      "dotfiles_sources" => {
        "ice_config" => "files/ice/com.jordanbaird.Ice.plist"
      }
    }
  end

  def test_complete_returns_false_by_default
    refute @step.complete?
  end

  def test_complete_when_configured
    stub_ice_configured
    assert @step.complete?
  end

  def test_complete_returns_false_when_preferences_missing
    stub_login_items("Ice")
    refute @step.complete?
  end

  def test_complete_returns_false_when_not_in_login_items
    stub_ice_preferences
    stub_login_items("")
    refute @step.complete?
  end

  def test_should_run_returns_false_when_ice_not_installed
    refute @step.should_run?
  end

  def test_should_run_returns_true_when_ice_installed_but_not_configured
    @fake_system.stub_file_content("/Applications/Ice.app", "app")
    assert @step.should_run?
  end

  def test_should_run_returns_false_when_ice_installed_and_configured
    @fake_system.stub_file_content("/Applications/Ice.app", "app")
    stub_ice_configured
    refute @step.should_run?
  end

  def test_run_copies_config_file
    src_config = File.join(@dotfiles_dir, "files/ice/com.jordanbaird.Ice.plist")
    dest_preferences = "#{@home}/Library/Preferences/com.jordanbaird.Ice.plist"

    @fake_system.stub_file_content(src_config, "plist content")
    @step.run

    assert @fake_system.received_operation?(:cp, src_config, dest_preferences)
  end

  def test_run_configures_launch_at_login
    stub_and_run
    assert @fake_system.received_operation?(:execute, "osascript -e 'tell application \"System Events\" to make login item at end with properties {path:\"/Applications/Ice.app\", hidden:false}'", {quiet: true})
  end

  def test_run_restarts_ice
    stub_and_run
    assert @fake_system.received_operation?(:execute, "killall Ice 2>/dev/null; open -a Ice", {quiet: true})
  end

  def test_update_copies_preferences_to_repo
    src_preferences = "#{@home}/Library/Preferences/com.jordanbaird.Ice.plist"
    dest_config = File.join(@dotfiles_dir, "files/ice/com.jordanbaird.Ice.plist")

    @fake_system.stub_file_content(src_preferences, "updated plist")
    @step.update

    assert @fake_system.received_operation?(:cp, src_preferences, dest_config)
  end

  def test_update_skips_when_preferences_missing
    @step.update
    refute @fake_system.received_operation?(:cp)
  end

  private

  def ice_config_path
    File.join(@dotfiles_dir, "files/ice/com.jordanbaird.Ice.plist")
  end

  def stub_ice_preferences
    @fake_system.stub_file_content("#{@home}/Library/Preferences/com.jordanbaird.Ice.plist", "plist content")
  end

  def stub_login_items(items)
    @fake_system.stub_command("osascript -e 'tell application \"System Events\" to get the name of every login item'", items, 0)
  end

  def stub_ice_configured
    stub_ice_preferences
    stub_login_items("Ice, OtherApp")
  end

  def stub_and_run
    @fake_system.stub_file_content(ice_config_path, "plist")
    @step.run
  end
end
