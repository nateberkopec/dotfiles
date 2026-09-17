require "test_helper"
require "json"
require "open3"

class OpenRouterUSCatalogTest < Minitest::Test
  CATALOG = File.expand_path("../../../files/home/.pi/agent/extensions/openrouter_us/catalog.ts", __dir__)
  US_BASE_URL = "https://us.openrouter.ai/api/v1"

  def test_intersection_keeps_only_regional_models_and_preserves_metadata
    result = run_catalog(<<~JS)
      const builtIn = [
        { id: "available", name: "Available", reasoning: true, baseUrl: "https://openrouter.ai/api/v1" },
        { id: "unavailable", name: "Unavailable", reasoning: false, baseUrl: "https://openrouter.ai/api/v1" }
      ];
      return catalog.intersectRegionalModels(builtIn, { data: [{ id: "available" }, { id: "unknown" }] }, #{US_BASE_URL.to_json});
    JS

    assert_equal ["available"], result.map { |model| model.fetch("id") }
    assert result.first.fetch("reasoning")
    assert_equal "Available", result.first.fetch("name")
    assert_equal US_BASE_URL, result.first.fetch("baseUrl")
  end

  def test_invalid_or_empty_discovery_fails_closed
    error = run_catalog(<<~JS)
      try {
        catalog.intersectRegionalModels([{ id: "built-in" }], { data: [{ id: "other" }] }, #{US_BASE_URL.to_json});
      } catch (error) {
        return error.message;
      }
    JS

    assert_equal "OpenRouter US model discovery matched no built-in models", error
  end

  def test_cache_is_restored_with_current_metadata_only_for_us_endpoint
    result = run_catalog(<<~JS)
      const builtIn = [{ id: "cached", contextWindow: 200000 }, { id: "other", contextWindow: 100000 }];
      return {
        restored: catalog.restoreRegionalModels(
          builtIn,
          [{ id: "cached", baseUrl: #{US_BASE_URL.to_json} }],
          #{US_BASE_URL.to_json}
        ),
        rejected: catalog.restoreRegionalModels(
          builtIn,
          [{ id: "cached", baseUrl: "https://openrouter.ai/api/v1" }],
          #{US_BASE_URL.to_json}
        )
      };
    JS

    assert_equal 200_000, result.fetch("restored").first.fetch("contextWindow")
    assert_equal US_BASE_URL, result.fetch("restored").first.fetch("baseUrl")
    assert_empty result.fetch("rejected")
  end

  private

  def run_catalog(body)
    script = <<~JS
      import(#{CATALOG.to_json}).then(async (catalog) => {
        const run = async () => {
          #{body}
        };
        console.log(JSON.stringify(await run()));
      });
    JS
    output, status = Open3.capture2e("node", "--no-warnings", "--input-type=module", "--eval", script)
    assert status.success?, output
    JSON.parse(output)
  end
end
