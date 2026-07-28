require "test_helper"

class MigrationRunnerTest < Minitest::Test
  def setup
    super
    @original_migrations = Dotfiles::Migration.class_variable_get(:@@migrations).dup
  end

  def teardown
    Dotfiles::Migration.class_variable_set(:@@migrations, @original_migrations)
    super
  end

  def test_run_if_existing_machine_skips_and_marks_latest_version_on_fresh_machine
    build_migration_class(900000000001)
    runner = build_runner

    capture_io { runner.run_if_existing_machine }

    assert_equal "900000000001\n", @fake_system.read_file(version_file)
    refute @fake_system.file_exist?(ran_file)
  end

  def test_run_if_existing_machine_skips_when_only_dotf_command_exists
    build_migration_class(900000000001)
    @fake_system.stub_file_content(File.join(@home, ".local", "bin", "dotf"), "dotf")
    runner = build_runner

    capture_io { runner.run_if_existing_machine }

    refute @fake_system.file_exist?(ran_file)
    assert_equal "900000000001\n", @fake_system.read_file(version_file)
  end

  def test_run_if_existing_machine_runs_when_version_file_exists
    build_migration_class(900000000001)
    @fake_system.stub_file_content(version_file, "0\n")
    runner = build_runner

    capture_io { runner.run_if_existing_machine }

    assert_equal "yes", @fake_system.read_file(ran_file)
    assert_equal "900000000001\n", @fake_system.read_file(version_file)
  end

  def test_run_still_runs_without_existing_machine_marker
    build_migration_class(900000000001)
    runner = build_runner

    capture_io { runner.run }

    assert_equal "yes", @fake_system.read_file(ran_file)
  end

  private

  def build_runner
    Dotfiles::MigrationRunner.new(nil, system: @fake_system, home: @home, dotfiles_dir: @dotfiles_dir, debug: false)
  end

  def build_migration_class(version)
    Class.new(Dotfiles::Migration) do
      const_set(:VERSION, version)

      define_singleton_method(:name) { "Dotfiles::Migration::TestMigration#{version}" }

      define_method(:up) do
        @system.write_file(File.join(@home, "migration-ran"), "yes")
      end

      define_method(:down) {}
    end
  end

  def version_file
    File.join(@home, ".local", "state", "dotf", "migration_version")
  end

  def ran_file
    File.join(@home, "migration-ran")
  end
end
