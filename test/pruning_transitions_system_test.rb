require "test_helper"
require_relative "support/pruning_system_fixture"

class PruningTransitionsSystemTest < Minitest::Test
  include PruningSystemFixture

  def test_unreadable_source_does_not_retire_managed_files
    skip "Root can read mode-zero directories" if Process.uid.zero?
    @items["extensions"]["optional"] = true
    configure
    successful_run
    before = @system.read_file(ledger_path)
    @system.chmod(0o000, File.join(@root, @source))
    _, status = run_pruning

    refute status.success?
    assert_equal before, @system.read_file(ledger_path)
    assert @system.file_exist?(File.join(@home, @target, "example.ts"))
  ensure
    @system.chmod(0o755, File.join(@root, @source))
  end

  def test_optional_external_symlinked_directory_is_not_adopted
    @items["extensions"]["optional"] = true
    configure
    redirect_destination
    successful_run

    assert_empty ledger.fetch("items")
    assert_equal "original", @system.read_file(File.join(@external, "example.ts"))
  end

  def test_existing_claim_survives_optional_external_symlinked_directory
    @items["extensions"]["optional"] = true
    configure
    successful_run
    before = ledger
    redirect_destination
    successful_run
    assert_equal before, ledger

    @items.clear
    configure
    _, status = run_pruning
    refute status.success?
    assert_equal before, ledger
    assert_equal "original", @system.read_file(File.join(@external, "example.ts"))
  end

  def test_renamed_optional_item_keeps_unverified_ownership
    @items["extensions"]["optional"] = true
    configure
    successful_run
    before = ledger
    write(File.join(@home, @target, "example.ts"), "local changes")
    @items["replacement"] = @items.delete("extensions")
    configure
    successful_run
    assert_equal before, ledger

    @items.clear
    configure
    _, status = run_pruning
    refute status.success?
    assert_equal before, ledger
    write(File.join(@home, @target, "example.ts"), "original")
    successful_run
    refute @system.file_exist?(File.join(@home, @target, "example.ts"))
  end

  def test_verified_file_directory_replacements_relinquish_obsolete_claims
    successful_run
    @system.rm_rf([File.join(@root, @source, "example.ts"), File.join(@home, @target, "example.ts")])
    deploy("example.ts/nested", "nested")
    successful_run
    successful_run
    assert_equal ["#{@target}/example.ts/nested"], ledger.fetch("items").fetch("extensions").fetch("files").keys

    @system.rm_rf([File.join(@root, @source, "example.ts"), File.join(@home, @target, "example.ts")])
    deploy("example.ts", "replacement")
    successful_run
    successful_run
    assert_equal ["#{@target}/example.ts"], ledger.fetch("items").fetch("extensions").fetch("files").keys
    assert_equal "replacement", @system.read_file(File.join(@home, @target, "example.ts"))
  end

  private

  def redirect_destination
    @external = File.join(@temporary, "external")
    write(File.join(@external, "example.ts"), "original")
    @system.rm_rf(File.join(@home, @target))
    @system.execute!(["ln", "-s", @external, File.join(@home, @target)])
  end
end
