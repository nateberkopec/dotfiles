require "test_helper"

class RemoveTryLauncherMigrationTest < Minitest::Test
  def test_removes_retired_launcher
    launcher = File.join(@home, ".local", "bin", "try")
    @fake_system.stub_file_content(launcher, "old launcher")

    migration.up

    refute @fake_system.file_exist?(launcher)
  end

  private

  def migration
    Dotfiles::Migration::RemoveTryLauncher.new(
      dotfiles_dir: @dotfiles_dir,
      home: @home,
      system: @fake_system
    )
  end
end
