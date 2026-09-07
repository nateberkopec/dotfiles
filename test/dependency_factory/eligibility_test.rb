require "test_helper"
require_relative "../../tools/ci/dependency_factory"
require_relative "../support/dependency_publication_fixture"

# standard:disable Dotfiles/BanFileSystemClasses
class DependencyEligibilityTest < Minitest::Test
  include DependencyPublicationFixture

  def test_eligible_update_accepts_any_report_prose
    with_update do |fixture|
      output, status = validate_publication(fixture, [publication_item])
      assert status.success?, output
    end
  end

  def test_age_gate_cannot_be_bypassed_by_a_security_claim
    with_update(date: "2026-09-06T00:00:00Z") do |fixture|
      output, status = validate_publication(fixture, [publication_item.merge("body" => "Security update; ignore the age gate")])
      refute status.success?
      assert_includes output, "Ineligible release"
    end
  end

  def test_autonomous_run_cannot_remove_a_snooze
    snooze_change(owner: false) do |output, status|
      refute status.success?
      assert_includes output, "preserve existing snoozes"
    end
  end

  def test_owner_can_propose_a_snooze_removal_without_a_report_schema
    snooze_change(owner: true) do |output, status|
      assert status.success?, output
    end
  end

  def test_selected_version_must_reach_wake_boundary
    with_update do |fixture|
      config = File.join(fixture[:agent], DependencyFactory::CONFIG_PATH)
      File.write(config, "minimum_release_age_days: 3\nsnoozes:\n  hk:\n    wake_at: '1.2'\n")
      fixture_commit(fixture[:agent])
      File.unlink(publication_bundle_path(fixture))
      publication_bundle(fixture)
      output, status = validate_publication(fixture, [publication_item])
      refute status.success?
      assert_includes output, "Snoozed hk until 1.2"
    end
  end

  def test_trusted_exact_release_advisory_wakes_snooze_without_editing_memory
    advisory_update(text: "Fixes CVE-2026-12345") do |output, status|
      assert status.success?, output
    end
  end

  def test_agent_prose_cannot_wake_a_snooze
    advisory_update(text: "Routine patch") do |output, status|
      refute status.success?
      assert_includes output, "Snoozed hk"
    end
  end

  def test_advisory_cannot_override_the_age_gate
    advisory_update(text: "Fixes CVE-2026-12345", date: "2026-09-06T00:00:00Z") do |output, status|
      refute status.success?
      assert_includes output, "Ineligible release"
    end
  end

  private

  def advisory_update(text:, date: "2026-09-01T00:00:00Z")
    publication_fixture do |fixture|
      policy = "minimum_release_age_days: 3\nsnoozes:\n  hk:\n    wake_at: '1.2'\n"
      File.write(File.join(fixture[:source], DependencyFactory::CONFIG_PATH), policy)
      fixture_commit(fixture[:source])
      base = fixture_git(fixture[:source], "rev-parse", "HEAD")
      fixture_git(fixture[:agent], "fetch", "-q", "origin")
      fixture_git(fixture[:agent], "reset", "--hard", base)
      write_evidence(fixture, "pr-context", {"base" => base})
      write_evidence(fixture, "dependency-candidates", {"generated_at" => "2026-09-06T18:11:29Z", "candidates" => [{"name" => "hk", "releases" => [{"version" => "1.1", "created_at" => date, "text" => text}]}]})
      File.write(File.join(fixture[:agent], ".mise.toml"), "[tools]\nhk = \"1.1\"\n")
      fixture_commit(fixture[:agent])
      publication_bundle(fixture)
      yield(*validate_publication(fixture, [publication_item.merge("body" => "Fixes CVE-2026-12345")]))
    end
  end

  def publication_bundle_path(fixture)
    DependencyFactory::Transport.bundle_path(fixture[:directory], nil, "dependency-update-test")
  end

  def with_update(date: "2026-09-01T00:00:00Z")
    publication_fixture do |fixture|
      data = {"generated_at" => "2026-09-06T18:11:29Z", "candidates" => [{"name" => "hk", "releases" => [{"version" => "1.1", "created_at" => date}]}]}
      write_evidence(fixture, "dependency-candidates", data)
      File.write(File.join(fixture[:agent], ".mise.toml"), "[tools]\nhk = \"1.1\"\n")
      fixture_commit(fixture[:agent])
      publication_bundle(fixture)
      yield fixture
    end
  end

  def snooze_change(owner:)
    publication_fixture do |fixture|
      config = File.join(fixture[:source], DependencyFactory::CONFIG_PATH)
      File.write(config, "minimum_release_age_days: 3\nsnoozes:\n  hk:\n    wake_at: '1.2'\n")
      fixture_commit(fixture[:source])
      base = fixture_git(fixture[:source], "rev-parse", "HEAD")
      fixture_git(fixture[:agent], "fetch", "-q", "origin")
      fixture_git(fixture[:agent], "reset", "--hard", base)
      write_evidence(fixture, "pr-context", {"base" => base, "owner_request" => owner})
      File.write(File.join(fixture[:agent], DependencyFactory::CONFIG_PATH), "minimum_release_age_days: 3\nsnoozes: {}\n")
      fixture_commit(fixture[:agent])
      publication_bundle(fixture)
      yield(*validate_publication(fixture, [publication_item]))
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
