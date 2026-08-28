require "test_helper"

class RemoveTodosExtensionMigrationTest < Minitest::Test
  def test_removes_global_extension
    @fake_system.stub_file_content(extension_path, "extension")

    migration.up

    refute @fake_system.file_exist?(extension_path)
  end

  private

  def migration
    Dotfiles::Migration::RemoveTodosExtension.new(
      dotfiles_dir: @dotfiles_dir,
      home: @home,
      system: @fake_system
    )
  end

  def extension_path
    File.join(@home, ".pi", "agent", "extensions", "todos.ts")
  end
end
