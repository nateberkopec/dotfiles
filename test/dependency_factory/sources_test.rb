require "test_helper"
require_relative "../../tools/ci/dependency_factory"

class DependencyFactorySourcesTest < Minitest::Test
  def test_npm_retains_repository_without_an_extra_request
    calls = []
    source = DependencyFactory::Sources.new(http: ->(url) do
      calls << url
      '{"repository":{"url":"https://github.com/owner/tool"},"time":{"created":"2025-01-01","1.0":"2026-01-01"}}'
    end)
    releases = source.npm("tool")
    assert_equal ["1.0"], releases.map { |release| release["version"] }
    assert_equal "https://github.com/owner/tool", releases.first.dig("repository", "url")
    assert_equal ["https://registry.npmjs.org/tool"], calls
  end

  def test_github_retains_body_and_excludes_drafts_and_prereleases
    source = DependencyFactory::Sources.new(http: ->(_url) do
      JSON.generate([
        {"tag_name" => "v1.0", "body" => "Fixed bug", "published_at" => "2026-01-01"},
        {"tag_name" => "v1.1", "draft" => true},
        {"tag_name" => "v1.2", "prerelease" => true}
      ])
    end)
    releases = source.github_releases("owner/tool", "v")
    assert_equal ["1.0"], releases.map { |release| release["version"] }
    assert_equal "Fixed bug", releases.first["text"]
  end

  def test_github_paginates_so_older_intermediate_releases_are_not_lost
    source = DependencyFactory::Sources.new(http: ->(url) do
      versions = url.end_with?("page=1") ? (101..200) : (99..100)
      JSON.generate(versions.map { |version| {"tag_name" => "v#{version}", "body" => "Release #{version}"} })
    end)
    assert_includes source.github_releases("owner/tool", "v").map { |release| release["version"] }, "99"
  end

  def test_response_body_rejects_oversized_evidence
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:read_body) { |&block| block.call("too large") }
    error = assert_raises(RuntimeError) { DependencyFactory::Sources.response_body(response, "https://example.test", 4) }
    assert_includes error.message, "exceeded 4 bytes"
  end
end
