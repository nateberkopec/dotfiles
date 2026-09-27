# standard:disable Dotfiles/BanFileSystemClasses -- black-box script tests require real temporary files
require_relative "../test_helper"
require "open3"
require "tmpdir"

class SkillCreatorScriptsTest < Minitest::Test
  ROOT = File.expand_path("../../files/home/.claude/skills/skill-creator", __dir__)
  PYTHON = ["uv", "run", "--no-project", "--with", "pyyaml==6.0.3", "python"]
  VALIDATE = File.join(ROOT, "scripts/quick_validate.py")

  def test_bundled_skill_validates_with_source_frontmatter
    output, status = Open3.capture2e(*PYTHON, VALIDATE, ROOT)

    assert status.success?, output
  end

  def test_validator_rejects_unexpected_frontmatter
    Dir.mktmpdir do |dir|
      skill = File.join(dir, "test-skill")
      Dir.mkdir(skill)
      File.write(File.join(skill, "SKILL.md"), "---\nname: test-skill\ndescription: Example\nunknown: value\n---\n")

      output, status = Open3.capture2e(*PYTHON, VALIDATE, skill)
      refute status.success?
      assert_includes output, "Unexpected key(s)"
    end
  end

  def test_packager_includes_skill_and_excludes_cache
    Dir.mktmpdir do |dir|
      output, status = Open3.capture2e(*PYTHON, "-m", "scripts.package_skill", ROOT, dir, chdir: ROOT)
      assert status.success?, output

      listing, status = Open3.capture2e("unzip", "-Z1", File.join(dir, "skill-creator.skill"))
      assert status.success?, listing
      assert_includes listing, "skill-creator/SKILL.md"
      assert_includes listing, "skill-creator/agents/grader.md"
      refute_includes listing, "__pycache__"
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
