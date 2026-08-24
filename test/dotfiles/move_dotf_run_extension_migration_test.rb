require "test_helper"

class MoveDotfRunExtensionMigrationTest < Minitest::Test
  def test_removes_global_extension
    global_extension_paths.each { |path| @fake_system.stub_file_content(path, "extension") }

    migration.up

    global_extension_paths.each { |path| refute @fake_system.file_exist?(path) }
  end

  private

  def migration
    Dotfiles::Migration::MoveDotfRunExtension.new(
      dotfiles_dir: @dotfiles_dir,
      home: @home,
      system: @fake_system
    )
  end

  def global_extension_paths
    base = File.join(@home, ".pi", "agent", "extensions", "dotf_run")
    [base, "#{base}.ts"]
  end
end
