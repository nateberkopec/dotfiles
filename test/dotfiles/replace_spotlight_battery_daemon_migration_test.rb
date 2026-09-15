require "test_helper"

class ReplaceSpotlightBatteryDaemonMigrationTest < Minitest::Test
  def test_without_legacy_system_artifacts_does_not_request_sudo
    migration.up

    refute @fake_system.received_operation_name?(:execute!)
  end

  def test_removes_obsolete_battery_daemon_and_user_sources
    source_dir = File.join(@home, ".local", "share", "spotlight")
    legacy_daemon = "/Library/LaunchDaemons/com.user.spotlight-battery.plist"
    @fake_system.stub_file_content(File.join(source_dir, "spotlight-battery.fish"), "old")
    @fake_system.stub_file_content(legacy_daemon, "old")

    migration.up

    refute @fake_system.dir_exist?(source_dir)
    command = @fake_system.operations.find do |operation|
      operation.first == :execute! && operation.flatten.join(" ").include?(legacy_daemon)
    end
    assert command, "Expected obsolete battery daemon to be removed"
    refute_includes command.flatten.join(" "), "local.spotlight-resume"
  end

  private

  def migration
    Dotfiles::Migration::ReplaceSpotlightBatteryDaemon.new(
      dotfiles_dir: @dotfiles_dir,
      home: @home,
      system: @fake_system
    )
  end
end
