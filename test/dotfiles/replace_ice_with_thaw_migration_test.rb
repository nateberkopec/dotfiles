require "test_helper"

class ReplaceIceWithThawMigrationTest < Minitest::Test
  include SystemAssertions

  def test_removes_old_login_item_and_cask_without_zapping_preferences
    @fake_system.stub_macos
    @fake_system.stub_command(brew_exists_command, "", exit_status: 0)
    @fake_system.stub_command(brew_command("list", "--cask", "jordanbaird-ice"), "jordanbaird-ice", exit_status: 0)
    @fake_system.stub_command(["pgrep", "-x", "Ice"], "123", exit_status: 0)

    migration.up

    assert_executed!(["osascript", "-e", 'tell application id "com.jordanbaird.Ice" to quit'])
    assert_executed!(login_item_removal)
    assert_executed!(brew_command("uninstall", "--cask", "jordanbaird-ice"))
    refute @fake_system.operations.any? { |operation| operation.flatten.join(" ").include?("zap") }
  end

  def test_removes_old_login_item_without_homebrew
    @fake_system.stub_macos
    @fake_system.stub_command(brew_exists_command, "", exit_status: 1)

    migration.up

    assert_executed!(login_item_removal)
    refute @fake_system.received_operation?(:execute!, brew_command("uninstall", "--cask", "jordanbaird-ice"), quiet: true)
  end

  private

  def migration
    Dotfiles::Migration::ReplaceIceWithThaw.new(dotfiles_dir: @dotfiles_dir, home: @home, system: @fake_system)
  end

  def brew_exists_command
    ["bash", "-c", 'command -v -- "$1" >/dev/null 2>&1', "dotfiles", "brew"]
  end

  def brew_command(*args)
    [{"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", *args]
  end

  def login_item_removal
    ["osascript", "-e", 'tell application "System Events"',
      "-e", 'if exists login item "Ice" then delete login item "Ice"', "-e", "end tell"]
  end
end
