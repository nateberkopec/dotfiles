require "test_helper"

class RemoveOpenRouterGuardrailMigrationTest < Minitest::Test
  def test_removes_global_extension_and_caches
    retired_files.each { |path| @fake_system.stub_file_content(path, "old") }

    migration.up

    refute @fake_system.file_exist?(extension_path)
    retired_files.each { |path| refute @fake_system.file_exist?(path) }
  end

  private

  def migration
    Dotfiles::Migration::RemoveOpenRouterGuardrail.new(
      dotfiles_dir: @dotfiles_dir,
      home: @home,
      system: @fake_system
    )
  end

  def extension_path
    File.join(@home, ".pi", "agent", "extensions", "openrouter_guardrail")
  end

  def retired_files
    cache_dir = File.join(@home, ".pi", "agent", "cache")
    [
      File.join(extension_path, "index.ts"),
      File.join(cache_dir, "openrouter-guardrail-models.json"),
      File.join(cache_dir, "openrouter-guardrail-performance.json")
    ]
  end
end
