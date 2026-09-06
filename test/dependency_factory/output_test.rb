require "test_helper"
require "json"
require "open3"
require "tmpdir"

# Real files exercise the post-step CLI in a separate process.
# standard:disable Dotfiles/BanFileSystemClasses
class DependencyFactoryOutputTest < Minitest::Test
  def test_empty_output_fails_instead_of_silently_succeeding
    assert_includes check([]), "The agent finished without a pull request outcome"
  end

  def test_comment_is_a_valid_no_change_outcome
    assert_equal "", check([{"type" => "add_comment"}])
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
    assert_includes check([item], context: {"number" => 2}), "Update the triggering pull request only"
    assert_includes check([item]), "No triggering pull request to update"
  end

  def test_bodies_cannot_bypass_validation_on_creation_or_revision
    %w[create_pull_request update_pull_request].each do |type|
      item = {"type" => type, "body" => "New body", "pull_request_number" => 2}
      context = {"base" => "invalid", "number" => ((type == "update_pull_request") ? 2 : nil)}
      items = (type == "update_pull_request") ? [{"type" => "push_to_pull_request_branch"}, item] : [item]
      assert_includes check(items, context: context), "Expected a commit SHA"
    end
  end

  def test_fixed_target_accepts_omitted_number_and_aliases
    [nil, "pr_number", "pr"].each do |key|
      item = {"type" => "update_pull_request", "body" => "New body"}
      item[key] = 2 if key
      items = [{"type" => "push_to_pull_request_branch"}, item]
      assert_includes check(items, context: {"number" => 2, "base" => "invalid"}), "Expected a commit SHA"
    end
  end

  def test_body_only_revision_cannot_leave_changed_pins_or_snoozes_unpublished
    item = {"type" => "update_pull_request", "body" => "Claims the snooze was changed"}
    assert_includes check([item], context: {"number" => 2, "head" => "HEAD"}, modified: true), "Changed checkout requires a branch push"
  end

  private

  def check(items, context: {}, modified: false)
    Dir.mktmpdir do |root|
      directory = File.join(root, "agent")
      Dir.mkdir(directory)
      File.write(File.join(root, "agent_output.json"), JSON.generate("items" => items))
      File.write(File.join(directory, "pr-context.json"), JSON.generate(context))
      changed_checkout(root) if modified
      script = File.expand_path("../../tools/ci/check_dependency_output.rb", __dir__)
      gemfile = File.expand_path("../../Gemfile", __dir__)
      output, = Open3.capture2e({"BUNDLE_GEMFILE" => gemfile}, "bundle", "exec", "ruby", script, directory, chdir: root)
      output
    end
  end

  def changed_checkout(root)
    File.write(File.join(root, "snooze.yml"), "wake_at: 1.0\n")
    git = ["git", "-C", root, "-c", "core.hooksPath=/dev/null"]
    Open3.capture2e(*git, "init", "--quiet")
    Open3.capture2e(*git, "add", "snooze.yml")
    Open3.capture2e(*git, "-c", "user.name=Test", "-c", "user.email=test@example.test", "commit", "--no-gpg-sign", "-qm", "Fixture")
    File.write(File.join(root, "snooze.yml"), "wake_at: 2.0\n")
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
