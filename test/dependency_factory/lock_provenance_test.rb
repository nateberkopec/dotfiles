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
    assert_equal ['fnox macos-arm64 provenance: "github-attestations" -> nil'], unattested.lost_since(before)
  end

  def test_a_lost_platform_entry_counts_as_lost_provenance
    before = provenance(entry("fnox", "linux-x64", verified: true) + entry("fnox", "macos-arm64", verified: true))

    assert_equal ['fnox macos-arm64 provenance: "github-attestations" -> nil'], provenance(entry("fnox", "linux-x64", verified: true)).lost_since(before)
  end

  def test_native_runs_report_newly_verified_platforms_only_for_their_platform
    committed = provenance(entry("fnox", "linux-x64", verified: false) + entry("fnox", "macos-arm64", verified: false))
    native = provenance(entry("fnox", "linux-x64", verified: false) + entry("fnox", "macos-arm64", verified: true))

    assert_equal ['fnox macos-arm64: provenance verified natively for version "1.0.0", checksum "sha256:original"'], committed.verified_by(native, "macos-arm64")
    assert_empty committed.verified_by(native, "linux-x64")
    assert_empty committed.unverified_by(native, "macos-arm64")
  end

  def test_claimed_verification_that_a_native_run_cannot_reproduce_is_an_error
    committed = provenance(entry("fnox", "macos-arm64", verified: true))
    native = provenance(entry("fnox", "macos-arm64", provenance: nil))

    assert_equal ["fnox macos-arm64: provenance_verified: true -> false does not match the natively verified artifact"], committed.unverified_by(native, "macos-arm64")
    assert_empty committed.verified_by(native, "macos-arm64")
  end

  def test_reads_nested_platform_tables_and_locks_without_tools
    nested = provenance("[tools.jq.platforms.linux-x64]\nurl = \"https://example.test/jq\"\nprovenance = \"github-attestations\"\nprovenance_verified = true\n")

    assert_equal ["jq linux-x64: provenance verified natively for version nil, checksum nil"], provenance("").verified_by(nested, "linux-x64")
  end

  def test_changing_the_provenance_type_is_reported
    before = provenance(entry("fnox", "macos-arm64", verified: true))
    after = provenance(entry("fnox", "macos-arm64", verified: true, provenance: "slsa"))

    assert_equal ['fnox macos-arm64 provenance: "github-attestations" -> "slsa"'], after.lost_since(before)
  end

  def test_native_verification_must_match_the_committed_artifact
    committed = provenance(entry("fnox", "macos-arm64", verified: true))
    other_version = provenance(entry("fnox", "macos-arm64", verified: true, version: "2.0.0"))
    other_checksum = provenance(entry("fnox", "macos-arm64", verified: true, checksum: "sha256:other"))

    assert_equal ['fnox macos-arm64: version: "1.0.0" -> "2.0.0" does not match the natively verified artifact'], committed.unverified_by(other_version, "macos-arm64")
    assert_equal ['fnox macos-arm64: checksum: "sha256:original" -> "sha256:other" does not match the natively verified artifact'], committed.unverified_by(other_checksum, "macos-arm64")
  end

  private

  def provenance(content)
    DependencyFactory::LockProvenance.new(content)
  end

  def entry(tool, platform, verified: false, provenance: "github-attestations", version: "1.0.0", checksum: "sha256:original")
    lines = ["[[tools.#{tool}]]", "version = \"#{version}\"", "[tools.#{tool}.\"platforms.#{platform}\"]", "url = \"https://example.test/#{tool}-#{platform}\"", "checksum = \"#{checksum}\""]
    lines << "provenance = \"#{provenance}\"" if provenance
    lines << "provenance_verified = true" if verified
    lines.join("\n") + "\n\n"
  end
end
