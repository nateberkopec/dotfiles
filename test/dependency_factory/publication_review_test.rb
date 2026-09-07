require "test_helper"
require_relative "../../tools/ci/dependency_factory"
require_relative "../support/dependency_publication_fixture"

# standard:disable Dotfiles/BanFileSystemClasses
class DependencyPublicationReviewTest < Minitest::Test
  include DependencyPublicationFixture

  def test_qualified_bundle_is_bound_and_ambiguous_alternative_is_rejected
    publication_fixture do |fixture|
      plain = publication_bundle(fixture)
      qualified = DependencyFactory::Transport.bundle_path(fixture[:directory], "test/test", "dependency-update-test")
      FileUtils.mv(plain, qualified)
      output, status = validate_publication(fixture, [publication_item])
      assert status.success?, output
      assert_includes File.read(File.join(fixture[:root], "publication.sha256")), qualified
      FileUtils.cp(qualified, plain)
      File.write(File.join(fixture[:agent], ".mise.toml"), "[tools]\nhk = \"9.9\"\n")
      fixture_commit(fixture[:agent])
      fixture_git(fixture[:agent], "bundle", "create", qualified, "dependency-update-test")
      output, status = validate_publication(fixture, [publication_item])
      refute status.success?
      assert_includes output, "Ambiguous queued bundles"
      assert_raises(RuntimeError) { DependencyFactory::Transport.errors(publication_item, directory: fixture[:directory], repo: "test/test") }
    end
  end

  def test_valid_report_update_cannot_request_an_unbundled_base_merge
    publication_fixture do |fixture|
      resume_publication(fixture, fixture[:base])
      item = publication_item.merge("type" => "update_pull_request", "pull_request_number" => 2)
      output, status = validate_publication(fixture, [item])
      assert status.success?, output
      output, status = validate_publication(fixture, [item.merge("update_branch" => true)])
      refute status.success?
      assert_includes output, "Branch updates require a validated bundle"
    end
  end

  def test_resume_preserves_snooze_added_after_comparison_base
    publication_fixture do |fixture|
      path = "config/dependency-updater.yml"
      File.write(File.join(fixture[:source], path), JSON.generate("snoozes" => {"hk" => {"candidate" => "1.1", "wake_at" => "2.0", "reason" => "Human wait"}}))
      fixture_commit(fixture[:source])
      head = fixture_git(fixture[:source], "rev-parse", "HEAD")
      fixture_git(fixture[:agent], "fetch", fixture[:source])
      fixture_git(fixture[:agent], "merge", "--ff-only", head)
      resume_publication(fixture, head)
      items = [publication_item.merge("type" => "push_to_pull_request_branch", "pull_request_number" => 2), publication_item.merge("type" => "update_pull_request", "pull_request_number" => 2)]
      publication_bundle(fixture)
      output, status = validate_publication(fixture, items)
      assert status.success?, output
      File.write(File.join(fixture[:agent], path), "snoozes: {}\n")
      fixture_commit(fixture[:agent])
      publication_bundle(fixture)
      output, status = validate_publication(fixture, items)
      refute status.success?
      assert_includes output, "existing snooze requires a human edit"
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
