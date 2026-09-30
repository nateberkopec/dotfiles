require "test_helper"

class RemoveImmutableFileFlagsMigrationTest < Minitest::Test
  include SystemAssertions

  def test_non_admin_removes_flags_from_existing_managed_files_without_sudo
    managed_files.each { |file| @fake_system.stub_file_content(file, "managed") }
    managed_files.each do |file|
      @fake_system.stub_command(["sudo", "chflags", "noschg,nouchg", file], "not in the sudoers file", exit_status: 1)
    end

    migration.up

    managed_files.each { |file| assert_executed(["chflags", "noschg,nouchg", file]) }
    assert_equal 0, @fake_system.operation_count(:execute!)
  end

  def test_retries_with_sudo_only_for_files_that_need_it
    managed_files.first(2).each { |file| @fake_system.stub_file_content(file, "managed") }
    @fake_system.stub_command(["chflags", "noschg,nouchg", managed_files.first], "Operation not permitted", exit_status: 1)

    migration.up

    assert_executed(["chflags", "noschg,nouchg", managed_files.first])
    assert_executed!(["sudo", "chflags", "noschg,nouchg", managed_files.first])
    assert_executed(["chflags", "noschg,nouchg", managed_files[1]])
    assert_equal 1, @fake_system.operation_count(:execute!)
  end

  def test_reports_failure_when_flags_require_sudo_but_sudo_is_denied
    file = managed_files.first
    @fake_system.stub_file_content(file, "managed")
    @fake_system.stub_command(["chflags", "noschg,nouchg", file], "Operation not permitted", exit_status: 1)
    @fake_system.stub_command(["sudo", "chflags", "noschg,nouchg", file], "not in the sudoers file", exit_status: 1)

    error = assert_raises(RuntimeError) { migration.up }

    assert_match(/not in the sudoers file/, error.message)
    assert_executed(["chflags", "noschg,nouchg", file])
    assert_executed!(["sudo", "chflags", "noschg,nouchg", file])
  end

  def test_does_not_change_externally_managed_git_hooks
    @fake_system.stub_file_content(File.join(@home, ".git-hooks/pre-commit"), "external")
    @fake_system.stub_file_content(File.join(@home, ".git-hooks/pre-push"), "external")

    assert_nil migration.up
    assert_equal 0, @fake_system.operation_count(:execute)
    assert_equal 0, @fake_system.operation_count(:execute!)
  end

  def test_does_nothing_when_managed_files_do_not_exist
    assert_nil migration.up
    assert_equal 0, @fake_system.operation_count(:execute)
    assert_equal 0, @fake_system.operation_count(:execute!)
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
