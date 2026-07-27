# standard:disable Dotfiles/BanFileSystemClasses -- black-box script tests require real temporary files
require_relative "../test_helper"
require "open3"
require "tmpdir"

class SkillCreatorScriptsTest < Minitest::Test
  ROOT = File.expand_path("../../files/home/.claude/skills/skill-creator/scripts", __dir__)
  INIT = File.join(ROOT, "init_skill.py")
  VALIDATE = File.join(ROOT, "quick_validate.py")

  def test_initializer_rejects_traversal_before_creation
    Dir.mktmpdir do |dir|
      _output, status = Open3.capture2e("python3", INIT, "../escape", "--path", dir)

      refute status.success?
      refute File.exist?(File.join(File.dirname(dir), "escape"))
      assert_empty Dir.children(dir)
    end
  end

  def test_initializer_generates_valid_frontmatter
    Dir.mktmpdir do |dir|
      _output, status = Open3.capture2e("python3", INIT, "valid-name", "--path", dir)

      assert status.success?
      output, status = Open3.capture2e("python3", VALIDATE, File.join(dir, "valid-name"))
      assert status.success?, output
    end
  end

  def test_validator_rejects_lookalike_fields_and_directory_mismatch
    Dir.mktmpdir do |dir|
      skill = File.join(dir, "actual-name")
      Dir.mkdir(skill)
      File.write(File.join(skill, "SKILL.md"), "---\nnotname: actual-name\nnodescription: nope\n---\n")
      _output, status = Open3.capture2e("python3", VALIDATE, skill)
      refute status.success?

      File.write(File.join(skill, "SKILL.md"), "---\nname: actual-name\ndescription: # absent\n---\n")
      _output, status = Open3.capture2e("python3", VALIDATE, skill)
      refute status.success?

      File.write(File.join(skill, "SKILL.md"), "---\nname: other-name\ndescription: Valid\n---\n")
      output, status = Open3.capture2e("python3", VALIDATE, skill)
      refute status.success?
      assert_includes output, "must match directory"
    end
  end

  def test_validator_accepts_multiline_description
    Dir.mktmpdir do |dir|
      skill = File.join(dir, "valid-name")
      Dir.mkdir(skill)
      File.write(File.join(skill, "SKILL.md"), <<~MD)
        ---
        name: valid-name
        description: |
          Create valid things.
          Use for validator checks.
        ---
      MD

      output, status = Open3.capture2e("python3", VALIDATE, skill)
      assert status.success?, output
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
