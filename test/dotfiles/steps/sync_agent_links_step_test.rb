require "test_helper"

class SyncAgentLinksStepTest < StepTestCase
  step_class Dotfiles::Step::SyncAgentLinksStep

  def setup
    super
    write_config("config", "dotagents_clients" => %w[claude codex])
    @fake_system.mkdir_p(File.join(@home, ".agents"))
  end

  def test_should_run_when_agent_links_are_out_of_sync
    stub_agents_file("AGENTS.md", "instructions")
    stub_agents_dir("skills")

    assert_should_run
  end

  def test_should_not_run_when_agent_links_are_in_sync
    stub_synced_agent_links

    refute_should_run
  end

  def test_run_syncs_existing_agent_sources_to_clients
    stub_agents_file("AGENTS.md", "instructions")
    stub_agents_dir("skills")

    step.run

    assert_command_run(:create_symlink, "../.agents/AGENTS.md", home_path(".claude/CLAUDE.md"))
    assert_command_run(:create_symlink, "../.agents/AGENTS.md", home_path(".codex/AGENTS.md"))
    assert_command_run(:create_symlink, "../.agents/skills", home_path(".claude/skills"))
    assert_command_run(:create_symlink, "../.agents/skills", home_path(".codex/skills"))
  end

  def test_run_prefers_claude_override_when_present
    stub_agents_file("AGENTS.md", "instructions")
    stub_agents_file("CLAUDE.md", "claude instructions")

    step.run

    assert_command_run(:create_symlink, "../.agents/CLAUDE.md", home_path(".claude/CLAUDE.md"))
  end

  def test_complete_when_links_are_in_sync
    stub_synced_agent_links

    assert_complete
  end

  def test_incomplete_when_link_missing
    stub_agents_file("AGENTS.md", "instructions")

    assert_incomplete
    assert_includes step.errors, "Agent link not in sync: ~/.claude/CLAUDE.md"
    assert_includes step.errors, "Agent link not in sync: ~/.codex/AGENTS.md"
  end

  def test_incomplete_without_agents_root
    @fake_system.rm_rf(File.join(@home, ".agents"))

    assert_incomplete
    assert_includes step.errors, "Missing ~/.agents; sync home directory first"
  end

  def test_complete_when_no_clients_configured
    write_config("config", "dotagents_clients" => [])
    current_step = rebuild_step!

    refute_should_run(current_step)
    assert_complete(current_step)
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
    path = home_path(relative)
    @fake_system.mkdir_p(File.dirname(path))
    @fake_system.stub_symlink(path, target)
  end

  def stub_synced_agent_links
    stub_agents_file("AGENTS.md", "instructions")
    stub_agents_dir("skills")
    stub_home_symlink(".claude/CLAUDE.md", "../.agents/AGENTS.md")
    stub_home_symlink(".codex/AGENTS.md", "../.agents/AGENTS.md")
    stub_home_symlink(".claude/skills", "../.agents/skills")
    stub_home_symlink(".codex/skills", "../.agents/skills")
  end
end
