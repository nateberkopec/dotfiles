require "test_helper"
require "json"
require "open3"
require "tmpdir"

# Real files exercise the post-step CLI in a separate process.
# standard:disable Dotfiles/BanFileSystemClasses
class DependencyFactoryOutputTest < Minitest::Test
  def test_empty_output_fails_instead_of_silently_succeeding
    assert_includes check([]), "The agent finished without an explicit outcome"
  end

  def test_comment_is_a_valid_no_change_outcome
    assert_equal "", check([{"type" => "add_comment", "item_number" => 2}], context: {"issue" => 2, "base" => "HEAD"})
  end

  def test_push_requires_refreshed_body
    assert_includes check([{"type" => "push_to_pull_request_branch"}]), "A branch push requires a refreshed pull request body"
  end

  def test_empty_or_appended_bodies_are_rejected
    assert_includes check([{"type" => "create_pull_request", "body" => ""}]), "The pull request body is empty"
    assert_includes check([{"type" => "update_pull_request", "operation" => "append", "body" => "Incomplete replacement"}]), "The pull request body must replace, not append"
  end

  def test_revisions_cannot_target_another_pr
    item = {"type" => "update_pull_request", "body" => "New body", "pull_request_number" => 3}
    assert_includes check([item], context: {"number" => 2}), "Update the active pull request only"
    assert_includes check([item]), "No active pull request to update"
  end

  def test_bodies_cannot_bypass_validation_on_creation_or_revision
    %w[create_pull_request update_pull_request].each do |type|
      item = {"type" => type, "body" => "New body", "pull_request_number" => 2}
      context = {"base" => "invalid", "head" => "HEAD", "number" => ((type == "update_pull_request") ? 2 : nil)}
      items = (type == "update_pull_request") ? [{"type" => "push_to_pull_request_branch"}, item] : [item]
      assert_includes check(items, context: context), "Expected a commit SHA"
    end
  end

  def test_noop_cannot_hide_unpublished_changes
    assert_equal "", check([{"type" => "noop", "message" => "Nothing useful to change"}], context: {"base" => "HEAD"})
    assert_includes check([{"type" => "noop"}], context: {"base" => "HEAD"}, modified: true), "No-change outcome has unpublished changes"
  end

  def test_comments_cannot_target_unrelated_issues
    assert_includes check([{"type" => "add_comment", "item_number" => 3}], context: {"issue" => 2}), "Comment must target the active batch or triggering issue"
  end

  private

  def check(items, context: {}, modified: false)
    Dir.mktmpdir do |root|
      directory = File.join(root, "agent")
      Dir.mkdir(directory)
      File.write(File.join(root, "agent_output.json"), JSON.generate("items" => items))
      File.write(File.join(directory, "pr-context.json"), JSON.generate(context))
      changed_checkout(root, modified)
      File.write(File.join(root, "gh"), "#!/bin/sh\nprintf HEAD\n")
      File.chmod(0o755, File.join(root, "gh"))
      script = File.expand_path("../../tools/ci/check_dependency_output.rb", __dir__)
      gemfile = File.expand_path("../../Gemfile", __dir__)
      output, = Open3.capture2e({"BUNDLE_GEMFILE" => gemfile, "GITHUB_REPOSITORY" => "test/test", "PATH" => "#{root}:#{ENV["PATH"]}"}, "bundle", "exec", "ruby", script, directory, chdir: root)
      output
    end
  end

  def changed_checkout(root, modified)
    File.write(File.join(root, "snooze.yml"), "wake_at: 1.0\n")
    git = ["git", "-C", root, "-c", "core.hooksPath=/dev/null"]
    Open3.capture2e(*git, "init", "--quiet")
    Open3.capture2e(*git, "add", "snooze.yml")
    Open3.capture2e(*git, "-c", "user.name=Test", "-c", "user.email=test@example.test", "commit", "--no-gpg-sign", "-qm", "Fixture")
    File.write(File.join(root, "snooze.yml"), "wake_at: 2.0\n") if modified
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
