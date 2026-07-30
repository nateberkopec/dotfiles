require "test_helper"

class AdoptMiseBootstrapMigrationTest < Minitest::Test
  include SystemAssertions

  def test_removes_old_macos_artifacts
    @fake_system.stub_macos
    old_files.each { |path| @fake_system.stub_file_content(path, "old") }

    migration.up

    old_files.each { |path| refute @fake_system.file_exist?(path) }
    assert_executed!(launchctl_command)
  end

  def test_removes_vestigial_debian_sources
    @fake_system.stub_debian
    apt_files.each { |path| @fake_system.stub_file_content(path, "old") }

    migration.up

    %w[azlux charm].each { |name| assert_executed!(apt_cleanup_command(name)) }
  end

  def test_is_idempotent
    @fake_system.stub_macos
    old_files.each { |path| @fake_system.stub_file_content(path, "old") }

    migration.up
    migration.up

    old_files.each { |path| refute @fake_system.file_exist?(path) }
    assert_executed!(launchctl_command)
  end

  private

  def migration
    Dotfiles::Migration::AdoptMiseBootstrap.new(
      dotfiles_dir: @dotfiles_dir,
      home: @home,
      system: @fake_system
    )
  end

  def old_files
    [
      File.join(@home, "Library", "LaunchAgents", "com.user.yknotify.plist"),
      File.join(@home, ".config", "fish", "conf.d", "macos.fish"),
      File.join(@home, ".config", "fish", "conf.d", "linux.fish"),
      File.join(@dotfiles_dir, "Brewfile")
    ]
  end

  def apt_files
    %w[azlux charm].flat_map do |name|
      ["/etc/apt/sources.list.d/#{name}.list", "/usr/share/keyrings/#{name}-archive-keyring.gpg"]
    end
  end

  def launchctl_command
    ["bash", "-c", 'launchctl bootout "gui/$(id -u)/$1" 2>/dev/null || true', "dotfiles", "com.user.yknotify"]
  end

  def apt_cleanup_command(name)
    [
      "bash", "-c", 'sudo rm -f "$1" "$2"', "dotfiles",
      "/etc/apt/sources.list.d/#{name}.list", "/usr/share/keyrings/#{name}-archive-keyring.gpg"
    ]
  end

  def assert_executed!(command)
    assert @fake_system.received_operation?(:execute!, command, {quiet: true}), "Expected #{command.inspect} to execute"
  end
end
