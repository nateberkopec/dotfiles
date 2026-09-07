require "test_helper"
require_relative "../../tools/ci/dependency_factory"
require_relative "../support/dependency_publication_fixture"

# standard:disable Dotfiles/BanFileSystemClasses
class DependencyPublicationRevisionTest < Minitest::Test
  include DependencyPublicationFixture

  def test_body_only_revision_has_no_bundle_requirement
    revision do |fixture, item|
      output, status = validate_publication(fixture, [item])
      assert status.success?, output
    end
  end

  def test_remote_head_changes_block_even_body_only_revisions
    revision(stale: true) do |fixture, item|
      output, status = validate_publication(fixture, [item])
      refute status.success?
      assert_includes output, "Stale PR"
    end
  end

  def test_unbundled_branch_update_is_rejected
    revision do |fixture, item|
      output, status = validate_publication(fixture, [item.merge("update_branch" => true)])
      refute status.success?
      assert_includes output, "Unexpected output fields"
    end
  end

  def test_snooze_added_at_starting_head_cannot_be_removed_autonomously
    revision do |fixture, item|
      config = DependencyFactory::CONFIG_PATH
      File.write(File.join(fixture[:agent], config), "minimum_release_age_days: 3\nsnoozes:\n  hk:\n    wake_at: '1.2'\n")
      fixture_commit(fixture[:agent])
      head = fixture_git(fixture[:agent], "rev-parse", "HEAD")
      fixture_git(fixture[:source], "fetch", "-q", fixture[:agent], "HEAD:refs/heads/trusted-head")
      write_evidence(fixture, "pr-context", {"number" => 1, "base" => fixture[:base], "head" => head, "branch" => "dependency-update-test"})
      File.write(File.join(fixture[:agent], config), "minimum_release_age_days: 3\nsnoozes: {}\n")
      fixture_commit(fixture[:agent])
      publication_bundle(fixture)
      push = {"type" => "push_to_pull_request_branch", "pull_request_number" => 1, "branch" => "dependency-update-test"}
      output, status = validate_publication(fixture, [item, push])
      refute status.success?
      assert_includes output, "preserve existing snoozes"
    end
  end

  private

  def revision(stale: false)
    publication_fixture do |fixture|
      write_evidence(fixture, "pr-context", {"number" => 1, "base" => fixture[:base], "head" => fixture[:base], "branch" => "dependency-update-test"})
      bin = File.join(fixture[:root], "bin")
      FileUtils.mkdir_p(bin)
      response = JSON.generate("head" => {"sha" => stale ? "0" * 40 : fixture[:base]}, "base" => {"ref" => "main"}, "state" => "open")
      File.write(File.join(bin, "gh"), "#!/bin/sh\nprintf '%s\\n' '#{response}'\n")
      File.chmod(0o755, File.join(bin, "gh"))
      old_path = ENV.fetch("PATH")
      begin
        ENV["PATH"] = "#{bin}:#{old_path}"
        yield fixture, {"type" => "update_pull_request", "pull_request_number" => 1, "body" => "A short revised report."}
      ensure
        ENV["PATH"] = old_path
      end
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
