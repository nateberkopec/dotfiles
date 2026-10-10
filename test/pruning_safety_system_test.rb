require "test_helper"
require_relative "support/pruning_system_fixture"

class PruningSafetySystemTest < Minitest::Test
  include PruningSystemFixture

  def test_missing_configuration_and_failed_deployments_do_not_prune
    successful_run
    deploy("another.ts", "new")
    @system.rm_rf(File.join(@home, @target, "another.ts"))
    @system.rm_rf(File.join(@root, @source, "example.ts"))
    before = @system.read_file(ledger_path)
    output, status = run_pruning
    refute status.success?
    assert_includes output, "not successfully deployed"
    assert_equal before, @system.read_file(ledger_path)
    assert @system.file_exist?(File.join(@home, @target, "example.ts"))

    @system.rm_rf(File.join(@root, "config/pruning.yml"))
    _, status = run_pruning
    refute status.success?
    assert_equal before, @system.read_file(ledger_path)
  end

  def test_symlinked_destination_parents_cannot_redirect_deletion
    successful_run
    outside = File.join(@temporary, "outside")
    write(File.join(outside, "example.ts"), "original")
    @system.rm_rf(File.join(@home, @target))
    @system.execute!(["ln", "-s", outside, File.join(@home, @target)])
    @system.rm_rf(File.join(@root, @source, "example.ts"))
    output, status = run_pruning

    refute status.success?
    assert_includes output, "Symlinked pruning parent"
    assert_equal "original", @system.read_file(File.join(outside, "example.ts"))
  end

  def test_corrupt_and_traversing_ledgers_fail_closed
    successful_run
    data = ledger
    fingerprint = data.fetch("items").fetch("extensions").fetch("files").values.first
    data["items"]["extensions"]["files"] = {"../outside" => fingerprint}
    write(ledger_path, JSON.generate(data))
    output, status = run_pruning
    refute status.success?
    assert_includes output, "Unsafe pruning path"
    assert @system.file_exist?(File.join(@home, @target, "example.ts"))

    write(ledger_path, "not json")
    _, status = run_pruning
    refute status.success?
    assert_equal "not json", @system.read_file(ledger_path)
  end

  def test_unknown_hooks_fail_before_any_deletion
    successful_run
    before = @system.read_file(ledger_path)
    @items["extensions"]["hook"] = {"type" => "shell", "command" => "exit 0"}
    configure
    @system.rm_rf(File.join(@root, @source, "example.ts"))
    output, status = run_pruning

    refute status.success?
    assert_includes output, "Unknown pruning hook"
    assert_equal before, @system.read_file(ledger_path)
    assert @system.file_exist?(File.join(@home, @target, "example.ts"))
  end
end
