require "test_helper"
require "toml-rb"

# Inspect repository fixtures, not the live home directory.
# standard:disable Dotfiles/BanFileSystemClasses
class AgentCompatibilityPathsTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_all_harnesses_share_canonical_skills
    %w[~/.agents/skills ~/.claude/skills ~/.codex/skills ~/.pi/agent/skills/claude].each do |destination|
      assert_canonical_link destination, "skills"
    end
    assert File.file?(File.join(ROOT, "tmp/agent-stuff/git/github.com/nateberkopec/agent-stuff/skills/dev-env-setup/SKILL.md"))
  end

  def test_all_harnesses_share_canonical_global_instructions
    dotfiles = TomlRB.load_file(File.join(ROOT, "files/home/.config/mise/config.toml")).fetch("dotfiles")
    %w[~/.claude/CLAUDE.md ~/.codex/AGENTS.md ~/.pi/agent/AGENTS.md].each do |destination|
      assert_equal({"source" => "~/.dotfiles/files/home/.agents/AGENTS.md", "mode" => "symlink"}, dotfiles.fetch(destination))
    end
    assert File.file?(File.join(ROOT, "files/home/.agents/AGENTS.md"))
  end

  def test_claude_only_keeps_harness_specific_settings
    %w[.claude .codex].each do |harness|
      directory = File.join(ROOT, "files/home", harness)
      instructions = (harness == ".claude") ? "CLAUDE.md" : "AGENTS.md"
      {instructions => "../.agents/AGENTS.md"}.each do |name, target|
        path = File.join(directory, name)
        assert File.symlink?(path)
        assert_equal target, File.readlink(path)
        assert_equal File.realpath(File.join(directory, target)), File.realpath(path)
      end
    end
    assert_equal ["CLAUDE.md", "settings.json"], Dir.children(File.join(ROOT, "files/home/.claude")).sort
    settings = JSON.parse(File.read(File.join(ROOT, "files/home/.claude/settings.json")))
    assert_equal false, settings.fetch("syncClaudeAiSkills")
  end

  private

  def assert_canonical_link(destination, relative_source)
    resources = YAML.safe_load_file(File.join(ROOT, "config/config.yml")).fetch("agent_resources")
    assert_equal relative_source, resources.fetch(destination.delete_prefix("~/"))
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
