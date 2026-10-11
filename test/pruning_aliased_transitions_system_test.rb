require "test_helper"
require_relative "support/pruning_system_fixture"

class PruningAliasedTransitionsSystemTest < Minitest::Test
  include PruningSystemFixture

  def test_file_directory_transitions_through_aliased_parents_can_retire
    alias_target = ".pi/agent/EXTENSIONS"
    skip "Requires a case-insensitive filesystem" unless @system.file_exist?(File.join(@home, alias_target, "example.ts"))
    successful_run
    write(File.join(@home, @target, "untracked"), "local")
    @system.rm_rf([File.join(@root, @source, "example.ts"), File.join(@home, @target, "example.ts")])
    deploy("example.ts/index.ts", "nested")
    @items["extensions"]["target"] = alias_target
    configure
    successful_run
    successful_run
    assert_equal ["#{alias_target}/example.ts/index.ts"], managed_paths

    @system.rm_rf([File.join(@root, @source, "example.ts"), File.join(@home, @target, "example.ts")])
    deploy("example.ts", "replacement")
    @items["extensions"]["target"] = @target
    configure
    successful_run
    successful_run
    assert_equal ["#{@target}/example.ts"], managed_paths
    assert_equal "replacement", @system.read_file(File.join(@home, @target, "example.ts"))

    @items.clear
    configure
    successful_run
    refute @system.file_exist?(File.join(@home, @target, "example.ts"))
    assert_empty ledger.fetch("items")
    assert_equal "local", @system.read_file(File.join(@home, @target, "untracked"))
  end

  private

  def managed_paths
    ledger.fetch("items").fetch("extensions").fetch("files").keys
  end
end
