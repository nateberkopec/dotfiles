require_relative "../test_helper"
require "open3"
require "tempfile"

class GithubReadmeAuditTest < Minitest::Test
  SCRIPT = File.expand_path("../../files/home/.claude/skills/github-readme/scripts/github_readme_audit.rb", __dir__)

  def test_fenced_headings_cannot_satisfy_structure
    markdown = <<~MD
      # Project

      Useful project.

      ```markdown
      # Fake second title
      ## Installation
      ## Usage
      ## License
      ```

      ```sh
      bundle install
      bundle exec rake test
      ```
    MD

    output, status = audit(markdown)

    refute status.success?
    assert_includes output, "[PASS] Exactly one H1"
    assert_includes output, "[FAIL] Installation section"
    assert_includes output, "[FAIL] Usage section"
  end

  def test_tilde_fences_are_ignored_and_real_headings_pass
    markdown = <<~MD
      # Project

      Useful project.

      ~~~~markdown
      # Fake title
      ~~~~

      ## Installation
      ```sh
      bundle install
      ```
      ## Usage
      ```sh
      bundle exec rake test
      ```
      ## License
      MIT
    MD

    output, status = audit(markdown)

    assert status.success?, output
    assert_includes output, "[PASS] Exactly one H1"
  end

  private

  def audit(markdown)
    Tempfile.create(["README", ".md"]) do |file|
      file.write(markdown)
      file.flush
      return Open3.capture2e("ruby", SCRIPT, file.path)
    end
  end
end
