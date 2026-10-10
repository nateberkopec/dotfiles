require "test_helper"
require_relative "support/pruning_system_fixture"

class PruningArtifactsSystemTest < Minitest::Test
  include PruningSystemFixture

  def test_active_snapshots_preserve_the_original_generated_artifact_baseline
    artifact = "Library/LaunchAgents/dev.mise.example.plist"
    @items["extensions"]["artifacts"] = [artifact]
    exercise_modified_artifact(artifact)
  end

  def test_renamed_hook_item_keeps_edited_plist_pending_without_unloading
    skip "LaunchAgents require macOS" unless RUBY_PLATFORM.include?("darwin")
    artifact = "Library/LaunchAgents/dev.mise.example.plist"
    @items["extensions"]["hook"] = {"type" => "launch_agent", "label" => "dev.mise.example"}
    executable = File.join(@temporary, "bin/launchctl")
    write(executable, "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$HOME/hook-log\"\nexit 0\n")
    @system.chmod(0o755, executable)
    exercise_modified_artifact(artifact, rename: true)
    assert_includes @system.read_file(File.join(@home, "hook-log")), "bootout gui/#{Process.uid}/dev.mise.example"
  end

  private

  def exercise_modified_artifact(artifact, rename: false)
    deployed = File.join(@home, artifact)
    write(deployed, "generated plist")
    configure
    successful_run
    baseline = ledger.fetch("items").fetch("extensions").fetch("files").fetch(artifact)
    write(deployed, "user-edited plist")
    id = rename ? "replacement" : "extensions"
    @items[id] = @items.delete("extensions") if rename
    configure
    successful_run
    successful_run
    assert_equal [id], ledger.fetch("items").keys
    assert_equal baseline, ledger.fetch("items").fetch(id).fetch("files").fetch(artifact)

    @items.clear
    configure
    output, status = run_pruning
    refute status.success?
    assert_includes output, "Preserving modified retired files"
    assert_equal "user-edited plist", @system.read_file(deployed)
    assert_equal baseline, ledger.fetch("items").fetch(id).fetch("files").fetch(artifact)
    assert @system.file_exist?(File.join(@home, @target, "example.ts"))
    refute @system.file_exist?(File.join(@home, "hook-log"))

    write(deployed, "generated plist")
    successful_run
    refute @system.file_exist?(deployed)
    refute @system.file_exist?(File.join(@home, @target, "example.ts"))
    assert_empty ledger.fetch("items")
  end
end
