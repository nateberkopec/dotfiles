# standard:disable Dotfiles/BanFileSystemClasses -- black-box linter tests require temporary skill trees
require_relative "../test_helper"
require_relative "../support/agent_skill_lint_helper"
require "tmpdir"

class AgentSkillEquivalenceLintTest < Minitest::Test
  include AgentSkillLintHelper

  def test_rejects_diverged_files_declared_identical
    Dir.mktmpdir do |root|
      body = "`left.md#dont` and `right.md#dont` must stay identical.\n"
      skill = write_skill(root, "paired", body: body)
      File.write(File.join(skill, "left.md"), "Unrelated left.\n## Don't\nleft\n")
      File.write(File.join(skill, "right.md"), "Unrelated right.\n## Don't\nright\n")

      output, status = run_skill_lint(root)
      refute status.success?
      assert_includes output, "paired-files-diverge"
    end
  end

  def test_rejects_a_prose_count_that_disagrees_with_its_table
    Dir.mktmpdir do |root|
      skill = write_skill(root, "counted", body: "The [table](table.md#target) has 3 columns.\n")
      tables = "| One | Two | Three |\n| --- | --- | --- |\n| A | B | C |\n\n## Target\n| One | Two |\n| --- | --- |\n| A | B |\n"
      File.write(File.join(skill, "table.md"), tables)

      output, status = run_skill_lint(root)
      refute status.success?
      assert_includes output, "prose-count-doesnt-match-referenced-table"
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
