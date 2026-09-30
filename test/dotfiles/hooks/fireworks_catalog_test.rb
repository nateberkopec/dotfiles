require "test_helper"
require "json"
require "open3"
require "tmpdir"
require "timeout"

class FireworksCatalogTest < Minitest::Test
  EXTENSION = File.expand_path("../../../files/home/.pi/agent/extensions/datasafe", __dir__)
  CATALOG = File.join(EXTENSION, "fireworks_catalog.ts")
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

  def test_online_rpc_refreshes_fireworks_after_startup
    # rubocop:disable Dotfiles/BanFileSystemClasses -- Pi needs a real isolated agent directory.
    Dir.mktmpdir("pi-fireworks-test") do |agent_dir|
      cached = model("accounts/fireworks/routers/kimi-k3-us")
      File.write(File.join(agent_dir, "models-store.json"), JSON.generate(
        "fireworks" => {"models" => [cached], "checkedAt" => 0}
      ))
      mock = File.join(agent_dir, "mock.ts")
      calls = File.join(agent_dir, "fetches.log")
      File.write(mock, <<~TS)
        import { appendFileSync } from "node:fs";
        import extension from #{EXTENSION.to_json};
        globalThis.fetch = async (input) => {
          const url = String(input);
          appendFileSync(#{calls.to_json}, `${url}\n`);
          if (url.endsWith("us-only-serverless.md")) return new Response(#{MARKDOWN.to_json});
          if (url.endsWith("/models")) return new Response(JSON.stringify({ data: #{[
            api_model("accounts/fireworks/models/kimi-k3"),
            api_model("accounts/fireworks/routers/new-model")
          ].to_json} }));
          throw new Error(`unexpected fetch: ${url}`);
        };
        export default extension;
      TS
      env = {"PI_CODING_AGENT_DIR" => agent_dir, "FIREWORKS_API_KEY" => "test-key", "PI_OFFLINE" => nil}
      output, stderr, status = Open3.capture3(env, "pi", "--no-extensions", "--extension", mock,
        "--list-models", "fireworks")
      assert status.success?, stderr
      assert_includes output, cached.fetch("id")
      refute File.exist?(calls), "--list-models must not wait for network discovery"

      Open3.popen3(env, "pi", "--no-extensions", "--extension", mock, "--mode", "rpc", "--no-session") do |stdin, stdout, errors, wait|
        begin
          Timeout.timeout(10) do
            loop do
              begin
                ids = JSON.parse(File.read(File.join(agent_dir, "models-store.json"))).fetch("fireworks").fetch("models").map { |entry| entry.fetch("id") }
                break if ids.include?("accounts/fireworks/routers/new-model-us")
              rescue JSON::ParserError
                # Another process is writing the cache.
              end
              raise "Pi exited before refresh: #{errors.read}" unless wait.alive?
              sleep 0.05
            end
            stdin.puts JSON.generate(id: "models", type: "get_available_models")
            loop do
              reply = JSON.parse(stdout.gets || raise("Pi exited without a model registry response"))
              next unless reply["id"] == "models"

              assert reply.fetch("success"), reply.inspect
              ids = reply.fetch("data").fetch("models").map { |entry| entry.fetch("id") }
              assert_includes ids, "accounts/fireworks/routers/new-model-us", "online discovery must update the active session registry"
              break
            end
          end
        ensure
          stdin.close
          stdout.read
          errors.read
        end
        assert wait.value.success?
      end
      assert_includes File.readlines(calls, chomp: true), "https://us.api.fireworks.ai/inference/v1/models"
    end
    # rubocop:enable Dotfiles/BanFileSystemClasses
  end

  def test_pi_loads_folder_extension_offline_and_ignores_old_global_cache
    # rubocop:disable Dotfiles/BanFileSystemClasses -- Pi needs a real isolated agent directory.
    Dir.mktmpdir("pi-fireworks-test") do |agent_dir|
      # rubocop:enable Dotfiles/BanFileSystemClasses
      system = Dotfiles::SystemAdapter.new
      valid = model("accounts/fireworks/routers/new-model-us")
      old_global = model("accounts/fireworks/models/kimi-k3", base_url: "https://api.fireworks.ai/inference/v1")
      system.write_file(File.join(agent_dir, "models-store.json"), JSON.pretty_generate(
        "fireworks" => {"models" => [old_global, valid], "checkedAt" => 1}
      ))
      system.write_file(File.join(agent_dir, "models.json"), JSON.generate("providers" => {}))

      stdout, stderr, status = Open3.capture3(
        {"PI_CODING_AGENT_DIR" => agent_dir, "PI_OFFLINE" => "1", "FIREWORKS_API_KEY" => "test-key"},
        "pi", "--no-extensions", "--extension", EXTENSION, "--list-models", "fireworks"
      )

      assert status.success?, stderr
      assert_includes stdout, valid.fetch("id")
      refute_includes stdout, old_global.fetch("id")
    end
  end

  private

  def api_model(id, image: false)
    {id: id, context_length: 200_000, supports_chat: true, supports_image_input: image}
  end

  def model(id, base_url: "https://us.api.fireworks.ai/inference/v1")
    {
      "id" => id,
      "name" => id,
      "provider" => "fireworks",
      "api" => "openai-completions",
      "baseUrl" => base_url,
      "reasoning" => true,
      "input" => ["text"],
      "cost" => {"input" => 0, "output" => 0, "cacheRead" => 0, "cacheWrite" => 0},
      "contextWindow" => 200_000,
      "maxTokens" => 131_072
    }
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
