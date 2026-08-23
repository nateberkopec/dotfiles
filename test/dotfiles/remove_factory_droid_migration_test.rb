require "test_helper"

class RemoveFactoryDroidMigrationTest < Minitest::Test
  include SystemAssertions

  def test_uninstalls_homebrew_cask_on_macos
    @fake_system.stub_macos
    @fake_system.stub_command(brew_command("list", "--cask", "droid"), "droid")

    create_migration.up

    assert_executed!(brew_command("uninstall", "--cask", "droid"))
  end

  def test_does_not_uninstall_homebrew_cask_off_macos
    create_migration.up

    refute_executed(brew_command("uninstall", "--cask", "droid"))
  end

  def test_removes_factory_user_files
    create_migration.up

    factory_paths.each { |path| assert @fake_system.received_operation?(:rm_rf, path) }
  end

  private

  def create_migration
    Dotfiles::Migration::RemoveFactoryDroid.new(
      dotfiles_dir: @dotfiles_dir,
      home: @home,
      system: @fake_system
    )
  end

  def factory_paths
    [
      File.join(@home, ".factory"),
      File.join(@home, ".local", "bin", "droid"),
      File.join(@home, ".cargo", "bin", "droid")
    ]
  end

  def brew_command(*args)
    [{"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", *args]
  end
end
