require "test_helper"

class SelfManageMiseMigrationTest < Minitest::Test
  include SystemAssertions

  def test_verifies_the_self_managed_binary
    prepare_migration

    migration.up

    assert_executed!([mise_bin, "--version"])
  end

  def test_requires_the_self_managed_binary
    stub_brew_missing

    error = assert_raises(RuntimeError) { migration.up }

    assert_includes error.message, mise_bin
  end

  def test_removes_homebrew_mise
    prepare_migration
    @fake_system.stub_command(brew_exists_command, "", exit_status: 0)
    @fake_system.stub_command(brew_command("list", "--formula", "mise"), "mise", exit_status: 0)

    migration.up

    assert_executed!(brew_command("uninstall", "mise"))
  end

  def test_removes_the_apt_package_and_repository
    prepare_migration
    @fake_system.stub_debian
    @fake_system.stub_command(["dpkg-query", "--show", "mise"], "mise", exit_status: 0)
    Dotfiles::Migration::SelfManageMise::APT_FILES.each { |path| @fake_system.stub_file_content(path, "stale") }

    migration.up

    assert_executed!(["sudo", "apt-get", "remove", "--yes", "mise"])
    assert_executed!(["bash", "-c", 'sudo rm -f "$@"', "dotfiles", *Dotfiles::Migration::SelfManageMise::APT_FILES])
  end

  private

  def prepare_migration
    @fake_system.stub_file_content(mise_bin, "binary")
    stub_brew_missing
  end

  def stub_brew_missing
    @fake_system.stub_command(brew_exists_command, "", exit_status: 1)
  end

  def migration
    Dotfiles::Migration::SelfManageMise.new(
      dotfiles_dir: @dotfiles_dir,
      home: @home,
      system: @fake_system
    )
  end

  def mise_bin
    File.join(@home, ".local", "bin", "mise")
  end

  def brew_exists_command
    ["bash", "-c", 'command -v -- "$1" >/dev/null 2>&1', "dotfiles", "brew"]
  end

  def brew_command(*args)
    [{"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", *args]
  end
end
