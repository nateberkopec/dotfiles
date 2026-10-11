require "test_helper"
require_relative "support/pruning_system_fixture"

class PruningNamesSystemTest < Minitest::Test
  include PruningSystemFixture

  def test_case_only_filename_rename_preserves_current_deployment
    skip "Requires a case-insensitive filesystem" unless @system.file_exist?(File.join(@home, @target, "EXAMPLE.ts"))
    successful_run
    [File.join(@root, @source), File.join(@home, @target)].each do |directory|
      @system.execute!(["mv", File.join(directory, "example.ts"), File.join(directory, "EXAMPLE.ts")])
    end
    successful_run
    successful_run

    assert_equal "original", @system.read_file(File.join(@home, @target, "EXAMPLE.ts"))
    assert_equal ["#{@target}/EXAMPLE.ts"], managed_paths
  end

  def test_case_only_parent_rename_preserves_current_deployment
    target = ".pi/agent/EXTENSIONS"
    skip "Requires a case-insensitive filesystem" unless @system.file_exist?(File.join(@home, target, "example.ts"))
    successful_run
    @items["extensions"]["target"] = target
    configure
    successful_run
    successful_run

    assert_equal "original", @system.read_file(File.join(@home, target, "example.ts"))
    assert_equal ["#{target}/example.ts"], managed_paths
  end

  def test_unverified_optional_case_alias_keeps_its_previous_claim
    skip "Requires a non-root case-insensitive filesystem" if Process.uid.zero? || !@system.file_exist?(File.join(@home, @target, "EXAMPLE.ts"))
    @items["extensions"]["optional"] = true
    configure
    successful_run
    before = ledger
    @system.execute!(["mv", File.join(@root, @source, "example.ts"), File.join(@root, @source, "EXAMPLE.ts")])
    @system.chmod(0o444, File.join(@home, @target, "example.ts"))
    successful_run

    assert_equal before, ledger
    assert_equal "original", @system.read_file(File.join(@home, @target, "EXAMPLE.ts"))
    @items.clear
    configure
    successful_run
    refute @system.file_exist?(File.join(@home, @target, "EXAMPLE.ts"))
  end

  def test_separate_hard_linked_names_still_retire_the_old_entry
    successful_run
    @system.execute!(["mv", File.join(@root, @source, "example.ts"), File.join(@root, @source, "replacement.ts")])
    @system.execute!(["ln", File.join(@home, @target, "example.ts"), File.join(@home, @target, "replacement.ts")])
    successful_run
    successful_run

    refute @system.file_exist?(File.join(@home, @target, "example.ts"))
    assert_equal "original", @system.read_file(File.join(@home, @target, "replacement.ts"))
    assert_equal ["#{@target}/replacement.ts"], managed_paths
  end

  def test_aliased_ledger_spelling_does_not_hide_a_separate_hard_link
    skip "Requires a case-insensitive filesystem" unless @system.file_exist?(File.join(@home, @target, "EXAMPLE.ts"))
    @system.execute!(["mv", File.join(@home, @target, "example.ts"), File.join(@home, @target, "EXAMPLE.ts")])
    successful_run
    @system.execute!(["mv", File.join(@root, @source, "example.ts"), File.join(@root, @source, "replacement.ts")])
    @system.execute!(["ln", File.join(@home, @target, "EXAMPLE.ts"), File.join(@home, @target, "replacement.ts")])
    successful_run
    successful_run

    refute @system.file_exist?(File.join(@home, @target, "EXAMPLE.ts"))
    assert_equal ["#{@target}/replacement.ts"], managed_paths
    @items.clear
    configure
    successful_run
    refute @system.file_exist?(File.join(@home, @target, "replacement.ts"))
    assert_empty ledger.fetch("items")
  end

  private

  def managed_paths
    ledger.fetch("items").fetch("extensions").fetch("files").keys
  end
end
