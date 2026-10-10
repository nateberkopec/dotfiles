require "test_helper"
require_relative "support/pruning_system_fixture"

class PruningFilesSystemTest < Minitest::Test
  include PruningSystemFixture

  def test_prunes_removed_files_but_keeps_untracked_files_and_configuration
    successful_run
    write(File.join(@home, @target, "local.ts"), "local")
    write(File.join(@home, ".gitconfig"), "preferences")
    @system.rm_rf(File.join(@root, @source, "example.ts"))
    output = successful_run

    assert_includes output, "Pruned #{@target}/example.ts"
    refute @system.file_exist?(File.join(@home, @target, "example.ts"))
    assert_equal "local", @system.read_file(File.join(@home, @target, "local.ts"))
    assert_equal "preferences", @system.read_file(File.join(@home, ".gitconfig"))
  end

  def test_modified_retired_files_remain_pending_until_resolved
    successful_run
    @system.rm_rf(File.join(@root, @source, "example.ts"))
    write(File.join(@home, @target, "example.ts"), "local changes")
    output, status = run_pruning

    refute status.success?
    assert_includes output, "Preserving modified retired files"
    assert ledger.fetch("items").fetch("extensions").fetch("files").key?("#{@target}/example.ts")
    assert_equal "local changes", @system.read_file(File.join(@home, @target, "example.ts"))
    @system.rm_rf(File.join(@home, @target, "example.ts"))
    successful_run
    assert_empty ledger.fetch("items")
  end

  def test_removing_a_declaration_uses_the_previous_ledger
    successful_run
    @items.clear
    configure
    successful_run

    refute @system.file_exist?(File.join(@home, @target, "example.ts"))
    refute @system.dir_exist?(File.join(@home, @target))
    assert @system.file_exist?(File.join(@root, @source, "example.ts"))
  end

  def test_successful_updates_refresh_fingerprints
    successful_run
    deploy("example.ts", "updated")
    successful_run
    @system.rm_rf(File.join(@root, @source, "example.ts"))
    successful_run

    refute @system.file_exist?(File.join(@home, @target, "example.ts"))
  end

  def test_owned_symlinks_are_unlinked_without_deleting_their_targets
    source = File.join(@root, @source, "example.ts")
    target = File.join(@home, @target, "example.ts")
    @items["extensions"]["source"] += "/example.ts"
    @items["extensions"]["target"] += "/example.ts"
    @items["extensions"]["mode"] = "symlink"
    @system.rm_rf(target)
    @system.execute!(["ln", "-s", source, target])
    configure
    successful_run
    @items.clear
    configure
    successful_run

    refute @system.symlink?(target)
    assert_equal "original", @system.read_file(source)
  end

  def test_optional_external_files_are_not_adopted
    @items["extensions"]["optional"] = true
    configure
    write(File.join(@home, @target, "example.ts"), "external installation")
    successful_run
    @items.clear
    configure
    successful_run

    assert_equal "external installation", @system.read_file(File.join(@home, @target, "example.ts"))
  end
end
