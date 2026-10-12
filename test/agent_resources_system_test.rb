require "test_helper"
require_relative "support/agent_resource_system_fixture"

class AgentResourcesSystemTest < Minitest::Test
  include AgentResourceSystemFixture

  def test_real_pinned_install_transfers_links_retires_copies_and_survives_pruning_and_repeat
    seed_legacy
    output, status = link_resources
    assert status.success?, output
    @config.fetch("agent_resources").each do |target, source|
      destination = File.join(@home, target)
      assert File.symlink?(destination), target
      assert_equal File.realpath(File.join(@package, source)), File.realpath(destination)
    end
    refute File.exist?(File.join(@home, ".pi/agent/extensions/notify.ts"))
    refute File.exist?(File.join(@home, ".pi/agent/prompts/plan-follow.md"))
    refute File.exist?(File.join(@package, "extensions/meridian.ts"))
    metadata = JSON.parse(File.read(File.join(@home, ".pi/agent/npm/node_modules/@nateberkopec/pi-meridian/package.json")))
    assert_equal "0.1.0-beta.1", metadata.fetch("version")
    assert_equal "custom extension", File.read(File.join(@home, ".pi/agent/extensions/custom.ts"))
    claimed = JSON.parse(File.read(ledger_path)).fetch("items").values.flat_map { |item| item.fetch("files").keys }
    refute_includes claimed, ".pi/agent/agents/reviewer.md"
    refute_includes claimed, ".agents/researcher.md"
    output, status = Open3.capture2e(environment.merge("DOTFILES_DIR" => @root), RbConfig.ruby,
      File.join(ROOT, "bin/lib/prune-managed-files.rb"))
    assert status.success?, output
    output, status = link_resources
    assert status.success?, output
    assert File.file?(File.join(@home, ".pi/agent/agents/reviewer.md"))
    File.unlink(File.join(@home, ".pi/agent/extensions/custom.ts"))
    output, status = Open3.capture2e(environment, "pi", "--no-approve", "--offline", "--list-models", chdir: @directory)
    assert status.success?, output
    refute_match(/Failed to load extension|collision|duplicate (skill|provider)/i, output)
  end

  def test_older_unchanged_deployed_versions_retire_using_the_pruning_ledger
    seed_legacy
    relative = ".pi/agent/extensions/notify.ts"
    legacy = File.join(@home, relative)
    File.write(legacy, "previous managed version")
    data = JSON.parse(File.read(ledger_path))
    data.fetch("items").fetch("old-resources").fetch("files").fetch(relative)["sha256"] = Digest::SHA256.file(legacy).hexdigest
    File.write(ledger_path, JSON.generate(data))
    output, status = link_resources
    assert status.success?, output
    refute File.exist?(legacy)
    assert File.symlink?(File.join(@home, ".pi/agent/agents/reviewer.md"))
  end

  def test_modified_legacy_resources_are_preserved_and_stop_the_transfer
    seed_legacy
    legacy = File.join(@home, ".pi/agent/extensions/notify.ts")
    File.write(legacy, "personal changes")
    output, status = link_resources
    refute status.success?
    assert_includes output, "Preserving modified extracted resources"
    assert_equal "personal changes", File.read(legacy)
    refute File.symlink?(File.join(@home, ".pi/agent/agents/reviewer.md"))
  end

  def test_missing_package_resource_prevents_deletion_of_legacy_copies
    seed_legacy
    File.unlink(File.join(@package, "agents/reviewer.md"))
    output, status = link_resources
    refute status.success?
    assert_includes output, "Agent package resource missing"
    assert File.file?(File.join(@home, ".pi/agent/extensions/notify.ts"))
    refute File.symlink?(File.join(@home, ".pi/agent/agents/reviewer.md"))
  end
end
