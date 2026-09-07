require "test_helper"
require_relative "../../tools/ci/dependency_factory"
require_relative "../support/dependency_publication_fixture"

class DependencyPublicationEnvelopeTest < Minitest::Test
  include DependencyPublicationFixture

  def test_native_comment_and_body_revision_target_aliases
    publication_fixture do |fixture|
      resume_publication(fixture, fixture[:base])
      native_items.each do |item|
        field = target_field(item)
        [field, "pr", "pr_number"].each do |name|
          output, status = validate_publication(fixture, [item.except(field).merge(name => 2)])
          assert status.success?, output
        end
        output, status = validate_publication(fixture, [item.merge("pr" => "2", "pr_number" => 2)])
        assert status.success?, output
      end
    end
  end

  def test_every_supplied_target_must_match_the_active_pr
    publication_fixture do |fixture|
      resume_publication(fixture, fixture[:base])
      native_items.each do |item|
        field = target_field(item)
        [field, "pr", "pr_number"].each do |name|
          [3, nil, ""].each do |target|
            output, status = validate_publication(fixture, [item.merge(name => target)])
            refute status.success?, output
            assert_includes output, "Unexpected target"
          end
        end
        output, status = validate_publication(fixture, [item.except(field)])
        refute status.success?, output
        assert_includes output, "Unexpected target"
      end
    end
  end

  def test_native_targets_require_an_active_pr
    publication_fixture do |fixture|
      native_items.each do |item|
        output, status = validate_publication(fixture, [item])
        refute status.success?, output
        assert_includes output, "Unexpected target"
      end
    end
  end

  def test_branch_changing_fields_remain_rejected
    publication_fixture do |fixture|
      resume_publication(fixture, fixture[:base])
      native_items.each do |item|
        {"update_branch" => true, "branch" => "other", "base" => "dependency-benchmark-642"}.each do |field, value|
          output, status = validate_publication(fixture, [item.merge(field => value)])
          refute status.success?, output
          assert_includes output, "Unexpected output fields"
        end
      end
    end
  end

  def test_native_comment_can_accompany_a_validated_push
    publication_fixture do |fixture|
      resume_publication(fixture, fixture[:base])
      publication_bundle(fixture)
      push = {"type" => "push_to_pull_request_branch", "branch" => "dependency-update-test", "pull_request_number" => 2}
      output, status = validate_publication(fixture, [push, native_items.first])
      assert status.success?, output
    end
  end

  private

  def target_field(item)
    (item.keys & %w[item_number pull_request_number]).first
  end

  def native_items
    [
      {"type" => "add_comment", "item_number" => 2, "body" => "Deferred pending compatibility evidence.", "repo" => "test/test", "temporary_id" => "aw_abc123", "secrecy" => "public", "integrity" => "none"},
      {"type" => "update_pull_request", "pull_request_number" => 2, "body" => "Revised release highlights and compatibility assessment.", "operation" => "replace", "repo" => "test/test"}
    ]
  end
end
