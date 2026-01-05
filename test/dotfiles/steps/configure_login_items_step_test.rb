require "test_helper"

class ConfigureLoginItemsStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureLoginItemsStep

  def setup
    super
    write_config("login_items", {"login_items" => ["/Applications/Trimmy.app"]})
  end

  def test_should_run_when_app_exists_but_not_in_login_items
    install_app("/Applications/Trimmy.app")
    stub_current_login_items([])
    assert_should_run
  end

  def test_should_not_run_when_app_already_in_login_items
    install_app("/Applications/Trimmy.app")
    stub_current_login_items(["/Applications/Trimmy.app"])
    refute_should_run
  end

  def test_should_not_run_when_app_not_installed
    stub_current_login_items([])
    refute_should_run
  end

  def test_should_not_run_with_empty_config
    write_config("login_items", {"login_items" => []})
    rebuild_step!
    stub_current_login_items([])
    refute_should_run
  end

  def test_ci_env_skips_configuration
    with_ci do
      install_app("/Applications/Trimmy.app")
      stub_current_login_items([])
      refute_should_run
      assert_complete
    end
  end

  def test_run_adds_missing_login_items
    install_app("/Applications/Trimmy.app")
    stub_current_login_items([])
    step.run
    assert_executed(add_login_item_command("/Applications/Trimmy.app"))
  end

  def test_run_skips_already_configured_items
    install_app("/Applications/Trimmy.app")
    stub_current_login_items(["/Applications/Trimmy.app"])
    step.run
    refute_executed(add_login_item_command("/Applications/Trimmy.app"))
  end

  def test_run_skips_missing_apps
    stub_current_login_items([])
    step.run
    refute_executed(add_login_item_command("/Applications/Trimmy.app"))
  end

  def test_complete_when_all_items_configured
    install_app("/Applications/Trimmy.app")
    stub_current_login_items(["/Applications/Trimmy.app"])
    assert_complete
  end

  def test_incomplete_when_items_missing
    install_app("/Applications/Trimmy.app")
    stub_current_login_items([])
    assert_incomplete
  end

  def test_complete_when_app_not_installed
    stub_current_login_items([])
    assert_complete
  end

  def test_handles_multiple_login_items
    write_config("login_items", {"login_items" => ["/Applications/Trimmy.app", "/Applications/Other.app"]})
    rebuild_step!
    install_app("/Applications/Trimmy.app")
    install_app("/Applications/Other.app")
    stub_current_login_items(["/Applications/Trimmy.app"])
    step.run
    refute_executed(add_login_item_command("/Applications/Trimmy.app"))
    assert_executed(add_login_item_command("/Applications/Other.app"))
  end

  private

  def install_app(path)
    @fake_system.filesystem[path] = :directory
  end

  def stub_current_login_items(items)
    output = items.join(", ")
    @fake_system.stub_command(list_login_items_command, output, exit_status: 0)
  end

  def list_login_items_command
    "osascript -e 'tell application \"System Events\" to get the path of every login item'"
  end

  def add_login_item_command(app_path)
    "osascript -e 'tell application \"System Events\" to make login item at end with properties {path:\"#{app_path}\", hidden:false}'"
  end
end
