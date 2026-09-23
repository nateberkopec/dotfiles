require "test_helper"

class ReplaceRaycastWithTinycastMigrationTest < Minitest::Test
  include SystemAssertions

  def test_uninstalls_managed_raycast_cask
    @fake_system.stub_macos
    @fake_system.stub_command(brew_exists_command, "", exit_status: 0)
    @fake_system.stub_command(brew_command("list", "--cask", "raycast"), "raycast", exit_status: 0)

    migration.up

    assert_executed!(brew_command("uninstall", "--cask", "raycast"))
  end

  def test_does_nothing_when_raycast_is_absent
    @fake_system.stub_macos
    @fake_system.stub_command(brew_exists_command, "", exit_status: 0)
    @fake_system.stub_command(brew_command("list", "--cask", "raycast"), "", exit_status: 1)

    migration.up

    refute @fake_system.received_operation?(
      :execute!, brew_command("uninstall", "--cask", "raycast"), {quiet: true}
    )
  end

  private

  def migration
    Dotfiles::Migration::ReplaceRaycastWithTinycast.new(
      dotfiles_dir: @dotfiles_dir,
      home: @home,
      system: @fake_system
    )
  end

  def brew_exists_command
    ["bash", "-c", 'command -v -- "$1" >/dev/null 2>&1', "dotfiles", "brew"]
  end

  def brew_command(*args)
    [{"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", *args]
  end
end
