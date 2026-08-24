require "test_helper"

class RemoveImmutableFileFlagsMigrationTest < Minitest::Test
  include SystemAssertions

  def test_removes_flags_from_existing_managed_files
    managed_files.each { |file| @fake_system.stub_file_content(file, "managed") }

    migration.up

    assert_executed!(["sudo", "chflags", "noschg,nouchg", *managed_files])
  end

  def test_does_nothing_when_managed_files_do_not_exist
    assert_nil migration.up
    refute_executed(["sudo", "chflags", "noschg,nouchg"])
  end

  private

  def migration
    Dotfiles::Migration::RemoveImmutableFileFlags.new(
      dotfiles_dir: @dotfiles_dir,
      home: @home,
      system: @fake_system
    )
  end

  def managed_files
    Dotfiles::Migration::RemoveImmutableFileFlags::MANAGED_PATHS.map do |path|
      File.join(@home, path)
    end
  end
end
