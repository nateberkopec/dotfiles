require "test_helper"
require_relative "support/pruning_system_fixture"

class PruningHooksSystemTest < Minitest::Test
  include PruningSystemFixture

  def test_empty_source_directory_retires_the_service_and_plist
    artifact = prepare_launch_agent
    successful_run
    @system.rm_rf(File.join(@root, @source, "example.ts"))
    successful_run

    refute @system.file_exist?(artifact)
    refute @system.file_exist?(File.join(@home, @target, "example.ts"))
    assert_includes @system.read_file(File.join(@home, "hook-log")), "bootout gui/#{Process.uid}/dev.mise.example"
    successful_run
    assert_empty ledger.fetch("items")
  end

  def test_renamed_item_does_not_unload_the_replacement_service
    artifact = prepare_launch_agent
    successful_run
    @items["replacement"] = @items.delete("extensions")
    @system.rm_rf(File.join(@root, @source, "example.ts"))
    deploy("replacement.ts", "replacement")
    configure
    successful_run

    refute @system.file_exist?(File.join(@home, "hook-log"))
    assert @system.file_exist?(artifact)
    assert @system.file_exist?(File.join(@home, @target, "replacement.ts"))
    refute @system.file_exist?(File.join(@home, @target, "example.ts"))
    assert_equal ["replacement"], ledger.fetch("items").keys
  end

  def test_failed_cleanup_hooks_preserve_files_and_retry_from_saved_metadata
    skip "LaunchAgents require macOS" unless RUBY_PLATFORM.include?("darwin")
    @items["extensions"]["hook"] = {"type" => "launch_agent", "label" => "dev.mise.example"}
    @items["extensions"]["artifacts"] = ["Library/LaunchAgents/dev.mise.example.plist"]
    artifact = File.join(@home, "Library/LaunchAgents/dev.mise.example.plist")
    write(artifact, "generated plist")
    configure
    successful_run
    @items.clear
    configure
    executable = File.join(@temporary, "bin/launchctl")
    write(executable, "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$HOME/hook-log\"\n[ \"$1\" = print ]\n")
    @system.chmod(0o755, executable)
    output, status = run_pruning

    refute status.success?
    assert_includes output, "Cannot unload"
    assert @system.file_exist?(artifact)
    assert @system.file_exist?(File.join(@home, @target, "example.ts"))
    assert_equal "launch_agent", ledger.fetch("items").fetch("extensions").fetch("hook").fetch("type")
    write(executable, "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$HOME/hook-log\"\nexit 0\n")
    successful_run
    refute @system.file_exist?(artifact)
    refute @system.file_exist?(File.join(@home, @target, "example.ts"))
    assert_includes @system.read_file(File.join(@home, "hook-log")), "bootout gui/#{Process.uid}/dev.mise.example"
  end

  private

  def prepare_launch_agent
    skip "LaunchAgents require macOS" unless RUBY_PLATFORM.include?("darwin")
    @items["extensions"]["hook"] = {"type" => "launch_agent", "label" => "dev.mise.example"}
    artifact = File.join(@home, "Library/LaunchAgents/dev.mise.example.plist")
    write(artifact, "generated plist")
    executable = File.join(@temporary, "bin/launchctl")
    write(executable, "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$HOME/hook-log\"\nexit 0\n")
    @system.chmod(0o755, executable)
    configure
    artifact
  end
end
