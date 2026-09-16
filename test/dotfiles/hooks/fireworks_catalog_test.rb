require "test_helper"
require "json"
require "open3"

class FireworksCatalogTest < Minitest::Test
  CATALOG = File.expand_path("../../../files/home/.pi/agent/extensions/fireworks_catalog.ts", __dir__)
  MARKDOWN = <<~MD
    # US-only Serverless

    ## Available models

    | Model | `model` ID |
    | --- | --- |
    | Kimi K3 | `accounts/fireworks/routers/kimi-k3-us` |
    | New Model | `accounts/fireworks/routers/new-model-us` |

    ## How to use it
  MD

  def test_documentation_table_is_the_exact_catalog
    result = run_catalog("parse", markdown: MARKDOWN)

    assert_equal [
      {"name" => "Kimi K3", "id" => "accounts/fireworks/routers/kimi-k3-us"},
      {"name" => "New Model", "id" => "accounts/fireworks/routers/new-model-us"}
    ], result
  end

  def test_metadata_is_matched_without_adding_api_only_models
    api_models = [
      api_model("accounts/fireworks/models/kimi-k3", image: true),
      api_model("accounts/fireworks/routers/new-model"),
      api_model("accounts/fireworks/models/not-in-docs")
    ]

    result = run_catalog("build", markdown: MARKDOWN, apiModels: api_models)

    assert_equal %w[accounts/fireworks/routers/kimi-k3-us accounts/fireworks/routers/new-model-us],
      result.map { |model| model.fetch("id") }
    assert_equal ["text", "image"], result.first.fetch("input")
    assert_equal 200_000, result.first.fetch("contextWindow")
    assert_equal 131_072, result.first.fetch("maxTokens")
  end

  def test_catalog_replacement_revokes_removed_models
    api_models = [
      api_model("accounts/fireworks/models/kimi-k3"),
      api_model("accounts/fireworks/routers/new-model")
    ]

    result = run_catalog("replace", markdown: MARKDOWN, apiModels: api_models)

    assert result.fetch("removedBlocked")
    assert_equal ["accounts/fireworks/routers/new-model-us"], result.fetch("ids")
  end

  def test_rejects_an_unsafe_documented_id
    markdown = MARKDOWN.sub("accounts/fireworks/routers/new-model-us", "accounts/other/models/not-us")

    error = assert_raises(RuntimeError) { run_catalog("parse", markdown: markdown) }

    assert_includes error.message, "unsafe model ID"
  end

  def test_rejects_partial_metadata_instead_of_publishing_a_partial_catalog
    error = assert_raises(RuntimeError) do
      run_catalog("build", markdown: MARKDOWN, apiModels: [api_model("accounts/fireworks/models/kimi-k3")])
    end

    assert_includes error.message, "new-model-us"
  end

  private

  def api_model(id, image: false)
    {id: id, context_length: 200_000, supports_chat: true, supports_image_input: image}
  end

  def run_catalog(operation, payload)
    script = <<~JS
      import { readFileSync } from "node:fs";
      const catalog = await import(#{CATALOG.to_json});
      const input = JSON.parse(readFileSync(0, "utf8"));
      const entries = catalog.parseUSModelCatalog(input.markdown);
      let result = entries;
      if (#{operation.to_json} === "build") result = catalog.buildUSModels(entries, input.apiModels);
      if (#{operation.to_json} === "replace") {
        const models = catalog.buildUSModels(entries, input.apiModels);
        const state = new catalog.USModelCatalog();
        state.replace(models);
        state.replace(models.slice(1));
        let removedBlocked = false;
        try { state.assertAllowed(models[0].id); } catch { removedBlocked = true; }
        result = { removedBlocked, ids: state.getModels().map(model => model.id) };
      }
      process.stdout.write(JSON.stringify(result));
    JS
    stdout, stderr, status = Open3.capture3("node", "--experimental-strip-types", "--input-type=module", "-e", script,
      stdin_data: JSON.generate(payload))
    raise stderr unless status.success?

    JSON.parse(stdout)
  end
end
