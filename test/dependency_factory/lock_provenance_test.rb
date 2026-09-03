require "test_helper"
require_relative "../../tools/ci/dependency_factory"

class DependencyFactoryLockProvenanceTest < Minitest::Test
  def test_an_unchanged_lock_loses_nothing_and_verifies_nothing_new
    lock = provenance(entry("fnox", "linux-x64", verified: false) + entry("fnox", "macos-arm64", verified: true))

    assert_empty lock.lost_since(lock)
    assert_empty lock.verified_by(lock, "macos-arm64")
    assert_empty lock.unverified_by(lock, "macos-arm64")
  end

  def test_losing_the_provenance_type_is_reported_but_losing_only_verification_is_not
    before = provenance(entry("fnox", "linux-x64", verified: true) + entry("fnox", "macos-arm64", verified: true))
    cross_generated = provenance(entry("fnox", "linux-x64", verified: true) + entry("fnox", "macos-arm64", verified: false))
    unattested = provenance(entry("fnox", "linux-x64", verified: true) + entry("fnox", "macos-arm64", provenance: nil))

    assert_empty cross_generated.lost_since(before)
    assert_equal ["fnox macos-arm64"], unattested.lost_since(before)
  end

  def test_a_lost_platform_entry_counts_as_lost_provenance
    before = provenance(entry("fnox", "linux-x64", verified: true) + entry("fnox", "macos-arm64", verified: true))

    assert_equal ["fnox macos-arm64"], provenance(entry("fnox", "linux-x64", verified: true)).lost_since(before)
  end

  def test_native_runs_report_newly_verified_platforms_only_for_their_platform
    committed = provenance(entry("fnox", "linux-x64", verified: false) + entry("fnox", "macos-arm64", verified: false))
    native = provenance(entry("fnox", "linux-x64", verified: false) + entry("fnox", "macos-arm64", verified: true))

    assert_equal ["fnox macos-arm64: provenance verified natively"], committed.verified_by(native, "macos-arm64")
    assert_empty committed.verified_by(native, "linux-x64")
    assert_empty committed.unverified_by(native, "macos-arm64")
  end

  def test_claimed_verification_that_a_native_run_cannot_reproduce_is_an_error
    committed = provenance(entry("fnox", "macos-arm64", verified: true))
    native = provenance(entry("fnox", "macos-arm64", provenance: nil))

    assert_equal ["fnox macos-arm64: provenance_verified could not be reproduced natively"], committed.unverified_by(native, "macos-arm64")
    assert_empty committed.verified_by(native, "macos-arm64")
  end

  def test_reads_nested_platform_tables_and_locks_without_tools
    nested = provenance("[tools.jq.platforms.linux-x64]\nurl = \"https://example.test/jq\"\nprovenance = \"github-attestations\"\nprovenance_verified = true\n")

    assert_equal ["jq linux-x64: provenance verified natively"], provenance("").verified_by(nested, "linux-x64")
  end

  private

  def provenance(content)
    DependencyFactory::LockProvenance.new(content)
  end

  def entry(tool, platform, verified: false, provenance: "github-attestations")
    lines = ["[[tools.#{tool}]]", "version = \"1.0.0\"", "[tools.#{tool}.\"platforms.#{platform}\"]", "url = \"https://example.test/#{tool}-#{platform}\""]
    lines << "provenance = \"#{provenance}\"" if provenance
    lines << "provenance_verified = true" if verified
    lines.join("\n") + "\n\n"
  end
end
