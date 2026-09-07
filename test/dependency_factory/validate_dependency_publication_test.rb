require "test_helper"
require_relative "../../tools/ci/dependency_factory"
require_relative "../support/dependency_publication_fixture"

# standard:disable Dotfiles/BanFileSystemClasses
class ValidateDependencyPublicationTest < Minitest::Test
  include DependencyPublicationFixture

  def test_default_no_change_validates_but_missing_outcome_does_not
    publication_fixture do |fixture|
      output, status = validate_publication(fixture)
      assert status.success?, output
      output, status = validate_publication(fixture, [])
      refute status.success?
      assert_includes output, "without an explicit outcome"
    end
  end

  def test_a_real_dependency_change_matches_the_queued_bundle_and_report
    publication_fixture do |fixture|
      source = "https://github.com/jdx/hk/releases/tag/v1.1"
      pin = {"name" => "hk", "current" => "1.0", "eligible" => "1.1", "latest" => "1.1", "published" => {"1.1" => "2026-09-01T00:00:00Z"}}
      write_evidence(fixture, "dependency-candidates", {"candidates" => [pin], "generated_at" => "2026-09-06T18:11:29Z", "minimum_release_age_days" => 3})
      write_evidence(fixture, "release-notes", {"packages" => {"hk" => [{"version" => "1.1", "url" => source, "text" => "Useful release notes"}]}})
      File.write(File.join(fixture[:agent], ".mise.toml"), "[tools]\nhk = \"1.1\"\n")
      fixture_commit(fixture[:agent])
      publication_bundle(fixture)
      row = {"name" => "hk", "version" => "1.1", "action" => "update", "reason" => "Useful release", "source" => source, "security" => false}
      body = "```json dependency-decisions\n#{JSON.generate("outcome" => "ready", "decisions" => [row])}\n```"
      output, status = validate_publication(fixture, [publication_item.merge("body" => body)])
      assert status.success?, output
    end
  end

  def test_trusted_evidence_cannot_be_rewritten_or_replaced_with_a_symlink
    publication_fixture do |fixture|
      path = File.join(fixture[:directory], "release-notes.json")
      File.write(path, '{"packages":{"invented":[]}}')
      output, status = validate_publication(fixture)
      refute status.success?
      assert_includes output, "Changed trusted evidence"
      File.unlink(path)
      File.symlink(File.join(fixture[:evidence], "release-notes.json"), path)
      assert_includes validate_publication(fixture).first, "Expected regular input"
    end
  end

  def test_extra_or_wrong_bundle_refs_are_rejected
    publication_fixture do |fixture|
      fixture_git(fixture[:agent], "branch", "other")
      [["other"], %w[dependency-update-test other]].each do |refs|
        publication_bundle(fixture, refs)
        assert_includes validate_publication(fixture, [publication_item]).first, "Unexpected bundle refs"
      end
    end
  end

  def test_malformed_bundle_cannot_pass_hash_verification
    publication_fixture do |fixture|
      path = publication_bundle(fixture)
      bytes = File.binread(path)
      bytes.setbyte(bytes.size - 1, bytes.getbyte(bytes.size - 1) ^ 255)
      File.binwrite(path, bytes)
      output, status = validate_publication(fixture, [publication_item])
      refute status.success?, output
    end
  end

  def test_symlink_modes_are_rejected
    publication_fixture do |fixture|
      File.unlink(File.join(fixture[:agent], ".mise.toml"))
      File.symlink("Gemfile", File.join(fixture[:agent], ".mise.toml"))
      fixture_commit(fixture[:agent])
      publication_bundle(fixture)
      assert_includes validate_publication(fixture, [publication_item]).first, "Forbidden dependency path or mode"
    end
  end

  def test_reverted_forbidden_files_are_rejected
    publication_fixture do |fixture|
      File.write(File.join(fixture[:agent], "unexpected"), "hidden history")
      fixture_commit(fixture[:agent])
      fixture_git(fixture[:agent], "rm", "unexpected")
      fixture_commit(fixture[:agent])
      publication_bundle(fixture)
      assert_includes validate_publication(fixture, [publication_item]).first, "Forbidden dependency path or mode"
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
