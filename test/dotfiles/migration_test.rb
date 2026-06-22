require "test_helper"

class MigrationTest < Minitest::Test
  include SystemAssertions

  def setup
    super
    @original_migrations = Dotfiles::Migration.class_variable_get(:@@migrations).dup
  end

  def teardown
    Dotfiles::Migration.class_variable_set(:@@migrations, @original_migrations)
    super
  end

  def test_macos_only_migration_is_allowed_on_macos
    @fake_system.stub_macos
    migration = create_migration(Dotfiles::Migration::MigrateBrewTapsToMise)

    assert migration.allowed_on_platform?
  end

  def test_macos_only_migration_is_not_allowed_off_macos
    migration = create_migration(Dotfiles::Migration::MigrateBrewTapsToMise)

    refute migration.allowed_on_platform?
  end

  def test_execute_raises_on_nonzero_status
    migration = create_migration(executing_migration_class("boom", quiet: false))
    @fake_system.stub_command("boom", "failed", exit_status: 1)

    error = assert_raises(RuntimeError) { migration.up }

    assert_includes error.message, "Command failed: boom"
    assert_executed!("boom", quiet: false)
  end

  def test_command_succeeds_remains_non_raising
    migration = create_migration(command_succeeds_migration_class("maybe"))
    @fake_system.stub_command("maybe", "no", exit_status: 1)

    migration.up

    assert_equal "false", @fake_system.read_file(File.join(@home, "command-succeeded"))
  end

  def test_hk_hook_migration_skips_absent_legacy_config
    @fake_system.mkdir_p(File.join(@dotfiles_dir, ".git"))
    stub_legacy_hook_config_absent
    migration = create_migration(Dotfiles::Migration::ReinstallDotfilesHkHook)

    migration.up

    refute_executed!("git -C #{@dotfiles_dir} config --local --unset-all hook.hk-pre-commit.command")
    refute_executed!("git -C #{@dotfiles_dir} config --local --unset-all hook.hk-pre-commit.event")
    assert_executed!(hk_install_command)
  end

  def test_hk_hook_migration_removes_present_legacy_config
    @fake_system.mkdir_p(File.join(@dotfiles_dir, ".git"))
    stub_legacy_hook_config_present
    migration = create_migration(Dotfiles::Migration::ReinstallDotfilesHkHook)

    migration.up

    assert_executed!("git -C #{@dotfiles_dir} config --local --unset-all hook.hk-pre-commit.command")
    assert_executed!("git -C #{@dotfiles_dir} config --local --unset-all hook.hk-pre-commit.event")
  end

  private

  def executing_migration_class(command_name, quiet: true)
    Class.new(Dotfiles::Migration) do
      const_set(:VERSION, 900000000001)
      define_method(:up) { execute(command(command_name), quiet: quiet) }
      define_method(:down) {}
    end
  end

  def command_succeeds_migration_class(command_name)
    Class.new(Dotfiles::Migration) do
      const_set(:VERSION, 900000000002)
      define_method(:up) do
        result = command_succeeds?(command(command_name))
        @system.write_file(File.join(@home, "command-succeeded"), result.to_s)
      end
      define_method(:down) {}
    end
  end

  def stub_legacy_hook_config_absent
    stub_legacy_hook_config(exit_status: 1)
  end

  def stub_legacy_hook_config_present
    stub_legacy_hook_config(exit_status: 0)
  end

  def stub_legacy_hook_config(exit_status:)
    %w[command event].each do |key|
      @fake_system.stub_command("git -C #{@dotfiles_dir} config --local --get-all hook.hk-pre-commit.#{key}", "", exit_status: exit_status)
    end
  end

  def hk_install_command
    ["bash", "-c", 'cd "$1" && hk install', "dotfiles", @dotfiles_dir]
  end

  def refute_executed!(command)
    refute @fake_system.received_operation?(:execute!, command, {quiet: true})
  end

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
