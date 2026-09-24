require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

# standard:disable Dotfiles/BanFileSystemClasses
class IntegrationChangeDetectionTest < Minitest::Test
  SCRIPT = File.expand_path("../tools/ci/detect_optional_integration.sh", __dir__)

  def setup
    @repo = Dir.mktmpdir("integration-change-detection")
    git("init", "-q")
    write("lib/dotfiles.rb", "baseline\n")
    commit("baseline")
  end

  def teardown
    FileUtils.remove_entry(@repo)
  end

  def test_pull_request_with_docs_only_is_optional
    base = head
    write("docs/guide.md", "prose\n")
    commit("docs")

    assert_detection "true", event: "pull_request", base: base
  end

  def test_docs_pull_request_ignores_runtime_changes_only_on_base_branch
    git("checkout", "-qb", "base")
    write("lib/dotfiles.rb", "runtime change\n")
    commit("base runtime change")
    base = head
    git("checkout", "-qb", "docs", "HEAD~1")
    write("docs/guide.md", "prose\n")
    commit("docs")

    assert_detection "true", event: "pull_request", base: base
    assert_detection "false", event: "push", base: base
  end

  def test_push_with_agent_markdown_and_skill_license_is_optional
    base = head
    %w[
      .agents/skills/needs-spec/SKILL.md
      files/home/.claude/CLAUDE.md
      files/home/.claude/skills/example/reference.md
      files/home/.claude/skills/example/LICENSE.txt
      files/home/.agents/researcher.md
      files/home/.pi/agent/agents/reviewer.md
    ].each { |path| write(path, "prose\n") }
    commit("agent prose")

    assert_detection "true", event: "push", base: base
  end

  def test_mixed_code_and_docs_is_not_optional
    base = head
    write("docs/guide.md", "prose\n")
    write("lib/dotfiles.rb", "runtime change\n")
    commit("mixed")

    assert_detection "false", event: "pull_request", base: base
  end

  def test_deleted_eligible_path_is_optional
    write("docs/old.md", "old prose\n")
    commit("add docs")
    base = head
    FileUtils.rm(File.join(@repo, "docs/old.md"))
    commit("delete docs", all: true)

    assert_detection "true", event: "pull_request", base: base
  end

  def test_rename_to_runtime_path_is_not_optional
    write("docs/guide.md", "prose\n")
    commit("add docs")
    base = head
    FileUtils.mkdir_p(File.join(@repo, "lib"))
    git("mv", "docs/guide.md", "lib/guide.rb")
    commit("move docs into runtime")

    assert_detection "false", event: "pull_request", base: base
  end

  def test_manual_runs_full_coverage
    assert_detection "false", event: "workflow_dispatch", base: head
  end

  def test_empty_diff_and_new_branch_push_run_full_coverage
    assert_detection "false", event: "push", base: head
    assert_detection "false", event: "push", base: "0" * 40
  end

  def test_failed_diff_fails_without_skip_output
    output, status, result = run_detection(event: "pull_request", base: "missing")

    refute status.success?, output
    assert_empty result
  end

  private

  def assert_detection(expected, event:, base:)
    output, status, result = run_detection(event: event, base: base)
    assert status.success?, output
    assert_equal "integration_optional=#{expected}\n", result
  end

  def run_detection(event:, base:)
    output_path = File.join(@repo, "github-output")
    FileUtils.rm_f(output_path)
    env = {"GITHUB_OUTPUT" => output_path, "RUNNER_TEMP" => @repo}
    output, status = Open3.capture2e(env, "/bin/bash", SCRIPT, event, base, head, chdir: @repo)
    result = File.exist?(output_path) ? File.read(output_path) : ""
    [output, status, result]
  end

  def write(path, content)
    absolute_path = File.join(@repo, path)
    FileUtils.mkdir_p(File.dirname(absolute_path))
    File.write(absolute_path, content)
  end

  def commit(message, all: false)
    git("add", "-A") unless all
    git("commit", "--no-gpg-sign", "-qam", message) if all
    git("commit", "--no-gpg-sign", "-qm", message) unless all
  end

  def head
    git("rev-parse", "HEAD").strip
  end

  def git(*arguments)
    output, status = Open3.capture2e(
      "git", "-c", "user.name=Test", "-c", "user.email=test@example.com", "-c", "core.hooksPath=/dev/null",
      *arguments, chdir: @repo
    )
    raise output unless status.success?

    output
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
