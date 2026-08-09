# frozen_string_literal: true

# standard:disable Dotfiles/BanFileSystemClasses -- black-box linter helpers require temporary skill trees

require "fileutils"
require "open3"

module AgentSkillLintHelper
  SCRIPT = File.expand_path("../../tools/lint_agent_skills.rb", __dir__)

  private

  def write_skill(root, name, frontmatter: nil, body: "Instructions.\n")
    path = File.join(root, name)
    FileUtils.mkdir_p(path)
    frontmatter ||= "name: #{File.basename(name)}\ndescription: Valid skill"
    File.write(File.join(path, "SKILL.md"), "---\n#{frontmatter}\n---\n#{body}")
    path
  end

  def run_skill_lint(root)
    Open3.capture2e(RbConfig.ruby, SCRIPT, root)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
