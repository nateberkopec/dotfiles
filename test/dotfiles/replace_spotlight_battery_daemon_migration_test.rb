require "test_helper"

class ReplaceSpotlightBatteryDaemonMigrationTest < Minitest::Test
  def test_removes_obsolete_daemon_sources_and_system_jobs
    source_dir = File.join(@home, ".local", "share", "spotlight")
    @fake_system.stub_file_content(File.join(source_dir, "spotlight-battery.fish"), "old")

    migration.up

    refute @fake_system.dir_exist?(source_dir)
    command = @fake_system.operations.find do |operation|
      operation.first == :execute! && operation.flatten.join(" ").include?("local.spotlight-resume.plist")
    end
    assert command, "Expected obsolete system jobs to be removed"
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
