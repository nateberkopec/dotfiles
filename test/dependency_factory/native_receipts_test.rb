require "test_helper"
require_relative "../../tools/ci/dependency_factory"
require_relative "../support/dependency_publication_fixture"

# standard:disable Dotfiles/BanFileSystemClasses
class DependencyNativeReceiptsTest < Minitest::Test
  include DependencyPublicationFixture

  def test_unchanged_proposal_requires_both_exact_native_receipts
    publication_fixture do |fixture|
      publication_bundle(fixture)
      output, status = validate_publication(fixture, [publication_item])
      assert status.success?, output
      File.unlink(File.join(fixture[:root], "receipts/macos-arm64.sha"))
      output, status = validate_publication(fixture, [publication_item])
      refute status.success?, output
      assert_includes output, "Missing or mismatched native receipt"
    end
  end

  def test_receipt_for_another_commit_is_rejected
    publication_fixture do |fixture|
      publication_bundle(fixture)
      File.write(File.join(fixture[:root], "receipts/linux-x64.sha"), "#{"0" * 40}\n")
      output, status = validate_publication(fixture, [publication_item])
      refute status.success?, output
      assert_includes output, "Missing or mismatched native receipt"
    end
  end

  def test_metadata_only_output_needs_no_receipts
    publication_fixture do |fixture|
      output, status = validate_publication(fixture)
      assert status.success?, output
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
