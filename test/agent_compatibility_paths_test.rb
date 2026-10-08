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
    assert File.file?(File.join(ROOT, "files/home/.agents/skills/dev-env-setup/SKILL.md"))
  end

  def test_all_harnesses_share_canonical_global_instructions
    %w[~/.claude/CLAUDE.md ~/.codex/AGENTS.md ~/.pi/agent/AGENTS.md].each do |destination|
      assert_canonical_link destination, "AGENTS.md"
    end
    assert File.file?(File.join(ROOT, "files/home/.agents/AGENTS.md"))
  end

  def test_claude_only_keeps_harness_specific_settings
    assert_equal ["settings.json"], Dir.children(File.join(ROOT, "files/home/.claude"))
  end

  private

  def assert_canonical_link(destination, relative_source)
    dotfiles = TomlRB.load_file(File.join(ROOT, "files/home/.config/mise/config.toml")).fetch("dotfiles")
    assert_equal({"source" => "~/.dotfiles/files/home/.agents/#{relative_source}", "mode" => "symlink"}, dotfiles.fetch(destination))
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
