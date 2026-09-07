require "test_helper"
require_relative "../../tools/ci/dependency_factory"
require_relative "../support/dependency_publication_fixture"

# standard:disable Dotfiles/BanFileSystemClasses
class DependencyPublicationTest < Minitest::Test
  include DependencyPublicationFixture

  def test_noop_needs_no_report
    publication_fixture do |fixture|
      output, status = validate_publication(fixture)
      assert status.success?, output
    end
  end

  def test_freeform_report_publishes_without_a_ledger
    publication_fixture do |fixture|
      publication_bundle(fixture)
      output, status = validate_publication(fixture, [publication_item])
      assert status.success?, output
    end
  end

  def test_native_creation_metadata_does_not_fail_after_research
    publication_fixture do |fixture|
      publication_bundle(fixture)
      item = publication_item.merge("base" => "dependency-benchmark-642", "repo" => "test/test", "draft" => true, "labels" => ["dependency-update"])
      output, status = validate_publication(fixture, [item])
      assert status.success?, output
    end
  end

  def test_native_diagnostic_metadata_is_accepted
    publication_fixture do |fixture|
      items = [
        {"type" => "missing_tool", "reason" => "No compiler", "tool" => "compiler", "alternatives" => ["Wait"]},
        {"type" => "missing_data", "reason" => "No notes", "data_type" => "release notes", "context" => "upstream unavailable", "alternatives" => ["Defer"]},
        {"type" => "report_incomplete", "reason" => "Infrastructure failure", "details" => "No source access"}
      ]
      output, status = validate_publication(fixture, items)
      assert status.success?, output
    end
  end

  def test_no_explicit_outcome_is_rejected
    publication_fixture do |fixture|
      output, status = validate_publication(fixture, [])
      refute status.success?, output
    end
  end

  def test_update_branch_cannot_bypass_bundle_validation
    publication_fixture do |fixture|
      publication_bundle(fixture)
      output, status = validate_publication(fixture, [publication_item.merge("update_branch" => true)])
      refute status.success?
      assert_includes output, "Unexpected output fields"
    end
  end

  def test_two_bundles_cannot_change_what_the_publisher_consumes
    publication_fixture do |fixture|
      path = publication_bundle(fixture)
      qualified = DependencyFactory::Transport.bundle_path(fixture[:directory], "test/test", "dependency-update-test")
      FileUtils.cp(path, qualified)
      output, status = validate_publication(fixture, [publication_item])
      refute status.success?
      assert_includes output, "Ambiguous queued bundles"
    end
  end

  def test_agent_checker_and_git_configuration_are_not_executed
    publication_fixture do |fixture|
      publication_bundle(fixture)
      File.write(File.join(fixture[:agent], "Gemfile"), 'abort "Agent Gemfile executed"')
      fixture_git(fixture[:agent], "config", "core.fsmonitor", "touch #{fixture[:root]}/poison")
      output, status = validate_publication(fixture, [publication_item])
      assert status.success?, output
      refute File.exist?(File.join(fixture[:root], "poison"))
    end
  end

  def test_unreported_ineligible_pin_cannot_be_published
    publication_fixture do |fixture|
      File.write(File.join(fixture[:agent], ".mise.toml"), "[tools]\nhk = \"9.9\"\n")
      fixture_commit(fixture[:agent])
      publication_bundle(fixture)
      output, status = validate_publication(fixture, [publication_item])
      refute status.success?, output
    end
  end

  def test_symlink_in_allowed_path_is_rejected
    publication_fixture do |fixture|
      path = File.join(fixture[:agent], ".mise.toml")
      File.unlink(path)
      File.symlink("Gemfile", path)
      fixture_commit(fixture[:agent])
      publication_bundle(fixture)
      output, status = validate_publication(fixture, [publication_item])
      refute status.success?
      assert_includes output, "Forbidden dependency path or mode"
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
