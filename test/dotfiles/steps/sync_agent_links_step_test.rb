require "test_helper"

class SyncAgentLinksStepTest < StepTestCase
  step_class Dotfiles::Step::SyncAgentLinksStep

  def setup
    super
    write_config("config", "dotagents_clients" => %w[claude codex])
    stub_agents_file("AGENTS.md", "# Shared instructions")
    stub_agents_dir("hooks")
    stub_agents_dir("skills")
    stub_agents_dir("commands")
    @fake_system.operations.clear
  end

  def test_run_creates_links_from_agents_root
    step.run

    assert_command_run(:create_symlink, "../.agents/AGENTS.md", home_path(".claude/CLAUDE.md"))
    assert_command_run(:create_symlink, "../.agents/AGENTS.md", home_path(".codex/AGENTS.md"))
    assert_command_run(:create_symlink, "../.agents/commands", home_path(".claude/commands"))
    assert_command_run(:create_symlink, "../.agents/commands", home_path(".codex/prompts"))
    assert_command_run(:create_symlink, "../.agents/hooks", home_path(".claude/hooks"))
    assert_command_run(:create_symlink, "../.agents/skills", home_path(".codex/skills"))
  end

  def test_run_creates_missing_source_directories
    @fake_system.rm_rf(agents_path("commands"))

    step.run

    assert_command_run(:mkdir_p, agents_path("commands"))
    assert_command_run(:create_symlink, "../.agents/commands", home_path(".claude/commands"))
  end

  def test_complete_when_links_are_in_sync
    stub_home_symlink(".claude/CLAUDE.md", "../.agents/AGENTS.md")
    stub_home_symlink(".codex/AGENTS.md", "../.agents/AGENTS.md")
    stub_home_symlink(".claude/commands", "../.agents/commands")
    stub_home_symlink(".codex/prompts", "../.agents/commands")
    stub_home_symlink(".claude/hooks", "../.agents/hooks")
    stub_home_symlink(".claude/skills", "../.agents/skills")
    stub_home_symlink(".codex/skills", "../.agents/skills")

    assert_complete
  end

  def test_run_backs_up_conflicting_targets_and_writes_manifest
    @fake_system.stub_file_content(home_path(".codex/AGENTS.md"), "old instructions")

    step.run

    assert backup_copy_for?(home_path(".codex/AGENTS.md"))
    assert backup_manifest_written?
  end

  def test_run_unprotects_conflicting_targets_on_macos
    @fake_system.stub_macos
    @fake_system.stub_file_content(home_path(".codex/AGENTS.md"), "old instructions")

    step.run

    assert_executed("sudo chflags -R nouchg,noschg #{home_path(".codex/AGENTS.md")}", quiet: false)
  end

  private

  def agents_path(relative)
    File.join(@home, ".agents", relative)
  end

  def home_path(relative)
    File.join(@home, relative)
  end

  def stub_agents_file(relative, content)
    path = agents_path(relative)
    @fake_system.mkdir_p(File.dirname(path))
    @fake_system.stub_file_content(path, content)
  end

  def stub_agents_dir(relative)
    @fake_system.mkdir_p(agents_path(relative))
  end

  def stub_home_symlink(relative, target)
    @fake_system.stub_symlink(home_path(relative), target)
  end

  def backup_copy_for?(path)
    @fake_system.operations.any? do |operation, source, destination|
      operation == :cp && source == path && destination.include?("/.agents/backup/")
    end
  end

  def backup_manifest_written?
    @fake_system.operations.any? do |operation, path, _content|
      operation == :write_file && path.include?("/.agents/backup/") && path.end_with?("manifest.json")
    end
  end
end
