# standard:disable Dotfiles/BanFileSystemClasses -- black-box linter tests require temporary skill trees
require_relative "../test_helper"
require_relative "../support/agent_skill_lint_helper"
require "json"
require "tmpdir"

class AgentSkillLintTest < Minitest::Test
  include AgentSkillLintHelper

  def test_accepts_valid_personal_skills_and_system_references
    Dir.mktmpdir do |root|
      write_skill(root, "helper")
      write_skill(root, "caller", body: "Run a `/helper` session. Run an `/imagegen` session.\n")
      guarded = "Never use WebFetch. Use WebSearch instead of WebFetch.\nDo not use WebFetch, use WebSearch.\nFor example, WebFetch(query: \"Ruby\").\n```text\nWebFetch(query: \"example\")\nSkill(skill: \"missing\")\n```\n"
      write_skill(root, "guarded", frontmatter: "name: guarded\ndescription: Guarded\nallowed-tools: WebSearch", body: guarded)
      write_skill(root, ".system/imagegen", frontmatter: "name: wrong")

      output, status = run_skill_lint(root)
      assert status.success?, output
    end
  end

  def test_rejects_unresolved_internal_skill_invocations
    Dir.mktmpdir do |root|
      body = "Run a `/missing` session. Skill(skill: \"also-missing\")\n"
      write_skill(root, "caller", body: body)

      output, status = run_skill_lint(root)
      refute status.success?
      assert_includes output, "/missing does not resolve"
      assert_includes output, "/also-missing does not resolve"
    end
  end

  def test_rejects_instructed_tools_missing_from_allowed_tools
    Dir.mktmpdir do |root|
      body = "WebSearch(query: \"Ruby\")\nRun this:\n\n```bash\nruby audit.rb\n```\n"
      frontmatter = "name: research\ndescription: Research\nallowed-tools: [Read, Bash(git:*)]"
      write_skill(root, "research", frontmatter: frontmatter, body: body)

      output, status = run_skill_lint(root)
      refute status.success?
      assert_includes output, "instructed-tool-not-in-allowed-tools"
      assert_includes output, "WebSearch"
      assert_includes output, "Bash"
    end
  end

  def test_accepts_allowed_tool_scopes_and_mcp_wildcards
    Dir.mktmpdir do |root|
      body = "mcp__docs__search(query: \"Ruby\")\nRun this:\n\n```bash\nbundle exec rake audit\n```\n"
      frontmatter = "name: docs\ndescription: Docs\nallowed-tools: [mcp__docs__*, Bash(bundle exec:*)]"
      write_skill(root, "docs", frontmatter: frontmatter, body: body)

      output, status = run_skill_lint(root)
      assert status.success?, output
    end
  end

  def test_rejects_nonsequential_eval_ids
    Dir.mktmpdir do |root|
      path = write_skill(root, "review")
      FileUtils.mkdir_p(File.join(path, "evals"))
      File.write(File.join(path, "evals", "evals.json"), JSON.generate(evals: [{id: 1}, {id: 3}]))

      output, status = run_skill_lint(root)
      refute status.success?
      assert_includes output, "eval-quality-issues"
    end
  end

  def test_enforces_documented_frontmatter_conventions
    Dir.mktmpdir do |root|
      write_skill(root, "actual", frontmatter: "name: Invalid_Name_That_Is_Much_Longer_Than_Forty_Characters\ndescription:")

      output, status = run_skill_lint(root)
      refute status.success?
      assert_includes output, "Skill name must match directory"
      assert_includes output, "Skill name must use 1–40 lowercase"
      assert_includes output, "Skill description is required"
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
