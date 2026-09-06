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
      assert_includes check([item], context: context), "Expected a commit SHA"
    end
  end

  private

  def check(items, context: {})
    Dir.mktmpdir do |root|
      directory = File.join(root, "agent")
      Dir.mkdir(directory)
      File.write(File.join(root, "agent_output.json"), JSON.generate("items" => items))
      File.write(File.join(directory, "pr-context.json"), JSON.generate(context))
      script = File.expand_path("../../tools/ci/check_dependency_output.rb", __dir__)
      output, = Open3.capture2e("bundle", "exec", "ruby", script, directory)
      output
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
