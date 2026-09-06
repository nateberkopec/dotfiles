require "test_helper"
require_relative "../../tools/ci/dependency_factory"

class DependencyFactoryVersionsTest < Minitest::Test
  Versions = DependencyFactory::Versions

  def test_stable_accepts_numeric_versions_with_a_letter_suffix_only
    assert Versions.stable?("3.7c")
    assert Versions.stable?("2026.8.14")
    refute Versions.stable?("4.1-dev")
    refute Versions.stable?("stable")
    refute Versions.stable?("0.0.0-20260324103239-0c773bdadedb")
  end

  def test_eligible_ignores_releases_inside_the_gate_while_latest_does_not
    releases = [
      {"version" => "1.0.0", "created_at" => "2026-08-01T00:00:00Z"},
      {"version" => "1.1.0", "created_at" => "2026-08-20T00:00:00Z"},
      {"version" => "1.2.0", "created_at" => "2026-08-31T00:00:00Z"},
      {"version" => "2.0.0-rc1", "created_at" => "2026-08-31T00:00:00Z"}
    ]
    cutoff = Time.utc(2026, 8, 29)

    assert_equal "1.1.0", Versions.eligible(releases, cutoff)
    assert_equal "1.2.0", Versions.latest(releases)
    assert_equal({"1.1.0" => "2026-08-20T00:00:00Z"}, Versions.published(releases, ["1.1.0"]))
  end
end
