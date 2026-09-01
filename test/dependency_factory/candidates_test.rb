require "test_helper"
require_relative "../../tools/ci/dependency_factory"

class DependencyFactoryCandidatesTest < Minitest::Test
  NOW = Time.utc(2026, 9, 1, 22, 0, 0)

  class FakeSources
    def mise(tool)
      {"gh" => releases("2.97.0" => "2026-08-01", "2.98.0" => "2026-08-20", "2.99.0" => "2026-09-01"),
       "jq" => releases("1.8.2" => "2026-01-01"),
       "rust" => releases("1.98.0" => "2026-07-01") + [{"version" => "stable", "created_at" => "2025-12-18T00:00:00Z"}]}.fetch(tool)
    end

    def npm(package)
      {"pi-subagents" => releases("0.37.2" => "2026-06-01", "0.63.0" => "2026-09-01"),
       "pi-ding" => releases("0.2.2" => "2026-02-01")}.fetch(package)
    end

    def gem(name)
      {"json" => releases("2.18.0" => "2026-05-01", "2.21.2" => "2026-08-10"),
       "standard" => releases("1.52.0" => "2026-06-01", "1.56.0" => "2026-08-15"),
       "minitest" => releases("5.25.0" => "2026-01-01"),
       "bundler" => releases("2.7.0" => "2026-01-01", "4.0.19" => "2026-08-01")}.fetch(name)
    end

    def github_releases(repo, prefix)
      {["jdx/mise", "v"] => releases("2026.8.10" => "2026-08-20", "2026.8.14" => "2026-08-26"),
       ["nateberkopec/vscodevim", "core-v"] => releases("1.32.4" => "2026-05-29")}.fetch([repo, prefix])
    end

    private

    def releases(versions)
      versions.map { |version, day| {"version" => version, "created_at" => "#{day}T00:00:00Z", "release_url" => "https://example.test/#{version}"} }
    end
  end

  def test_builds_candidates_from_every_manifest_and_batches_gems
    result = DependencyFactory::Candidates.new(sources: FakeSources.new, days: 3, now: NOW).build(pins)
    names = result["candidates"].map { |candidate| candidate["name"] }

    assert_equal ["mise", "gh", "pi:pi-subagents", "bundler", "Gemfile.lock"], names
    gh = result["candidates"].find { |candidate| candidate["name"] == "gh" }
    assert_equal "2.98.0", gh["eligible"]
    assert_equal "2.99.0", gh["latest"]
    assert_equal "https://example.test/2.98.0", gh["source"]
    assert_equal({"2.98.0" => "2026-08-20T00:00:00Z", "2.99.0" => "2026-09-01T00:00:00Z"}, gh["published"])
  end

  def test_pi_package_inside_the_gate_is_a_candidate_whose_eligible_release_is_the_current_pin
    result = DependencyFactory::Candidates.new(sources: FakeSources.new, days: 3, now: NOW).build(pins)
    pi = result["candidates"].find { |candidate| candidate["name"] == "pi:pi-subagents" }

    assert_equal "0.37.2", pi["eligible"]
    assert_equal "0.63.0", pi["latest"]
  end

  def test_gem_batch_lists_only_gems_that_are_behind
    result = DependencyFactory::Candidates.new(sources: FakeSources.new, days: 3, now: NOW).build(pins)
    batch = result["candidates"].find { |candidate| candidate["name"] == "Gemfile.lock" }

    assert_equal %w[json standard], batch["members"].map { |member| member["name"] }
    assert_equal "2 gems behind", batch["current"]
  end

  def test_unpinned_and_unstable_pins_are_observation_only
    result = DependencyFactory::Candidates.new(sources: FakeSources.new, days: 3, now: NOW).build(pins)

    assert_equal ["go:github.com/noperator/yknotify", "pi:git:github.com/nijaru/pi-fast-mode@85c8b6"], result["observation_only"].map { |pin| pin["name"] }
  end

  private

  def pins
    [["config/mise.version", "2026.8.10\n"],
      ["files/home/.config/mise/config.toml", <<~TOML],
        [tools]
        gh = "2.97.0"
        jq = "1.8.2"
        rust = "1.98.0"
        "go:github.com/noperator/yknotify" = "0.0.0-20260324103239-0c773bdadedb"
      TOML
      ["files/home/.pi/agent/settings.json", '{"packages": ["npm:pi-subagents@0.37.2", "npm:pi-ding@0.2.2", "git:github.com/nijaru/pi-fast-mode@85c8b6"]}'],
      ["Gemfile.lock", <<~LOCK],
        GEM
          remote: https://rubygems.org/
          specs:
            json (2.18.0)
            minitest (5.25.0)
            standard (1.52.0)
              json (>= 2.0)

        PLATFORMS
          ruby

        DEPENDENCIES
          standard

        BUNDLED WITH
           2.7.0
      LOCK
      ["config/config.yml", "vscode_extension_sources:\n  nateberkopec.vscodevim-core:\n    github: nateberkopec/vscodevim\n    tag: core-v1.32.4\n    asset: vscodevim-core-1.32.4.vsix\n"]]
      .flat_map { |path, content| DependencyFactory::Manifests.pins(path, content) }
  end
end
