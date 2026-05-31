require "test_helper"

class MigrationTest < Minitest::Test
  def test_macos_only_migration_is_allowed_on_macos
    @fake_system.stub_macos
    migration = create_migration(Dotfiles::Migration::MigrateBrewTapsToMise)

    assert migration.allowed_on_platform?
  end

  def test_macos_only_migration_is_not_allowed_off_macos
    migration = create_migration(Dotfiles::Migration::MigrateBrewTapsToMise)

    refute migration.allowed_on_platform?
  end

  private

  def create_migration(migration_class, **overrides)
    defaults = {
      debug: false,
      dotfiles_repo: "https://github.com/test/dotfiles.git",
      dotfiles_dir: @dotfiles_dir,
      home: @home,
      system: @fake_system
    }
    migration_class.new(**defaults.merge(overrides))
  end
end
