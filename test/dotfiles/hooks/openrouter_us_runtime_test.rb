# standard:disable Dotfiles/BanFileSystemClasses -- black-box extension tests need isolated Pi config files
require "test_helper"
require "json"
require "open3"
require "tmpdir"

class OpenRouterUSRuntimeTest < Minitest::Test
  INDEX = File.expand_path("../../../files/home/.pi/agent/extensions/openrouter_us/index.ts", __dir__)
  MODEL_A = "anthropic/claude-3-haiku"
  MODEL_B = "google/gemini-2.5-pro"

  def setup
    missing = %w[mise node pi].reject { |command| command_available?(command) }
    skip "requires managed Pi runtime: #{missing.join(", ")}" unless missing.empty?
  end

  def test_repeated_online_refreshes_restore_the_us_snapshot_offline
    result = run_runtime(<<~JS)
      const store = new ai.InMemoryModelsStore();
      const catalogs = [[#{MODEL_A.to_json}], [#{MODEL_A.to_json}]];
      const calls = [];
      globalThis.fetch = async (input) => {
        const url = String(input);
        calls.push(url);
        const ids = url.includes("pi.dev") ? [#{MODEL_B.to_json}] : catalogs.shift();
        return new Response(JSON.stringify({ data: ids.map((id) => ({ id })) }));
      };

      const online = ai.createModels({ modelsStore: store });
      online.setProvider(makeProvider());
      await online.refresh({ allowNetwork: true, force: true });
      await online.refresh({ allowNetwork: true, force: true });

      const offline = ai.createModels({ modelsStore: store });
      offline.setProvider(makeProvider());
      await offline.refresh({ allowNetwork: false });
      return { calls, ids: offline.getModels("openrouter").map((model) => model.id) };
    JS

    assert_equal ["https://us.openrouter.ai/api/v1/models"] * 2, result.fetch("calls")
    assert_equal [MODEL_A], result.fetch("ids")
  end

  def test_reload_uses_the_raw_catalog_and_discovers_new_regional_models
    result = run_runtime(<<~JS)
      const store = new ai.InMemoryModelsStore();
      const catalogs = [[#{MODEL_A.to_json}], [#{MODEL_A.to_json}, #{MODEL_B.to_json}]];
      globalThis.fetch = async () => {
        const ids = catalogs.shift();
        return new Response(JSON.stringify({ data: ids.map((id) => ({ id })) }));
      };

      const beforeReload = ai.createModels({ modelsStore: store });
      beforeReload.setProvider(makeProvider());
      await beforeReload.refresh({ allowNetwork: true, force: true });

      const afterReload = ai.createModels({ modelsStore: store });
      afterReload.setProvider(makeProvider());
      await afterReload.refresh({ allowNetwork: true, force: true });
      return afterReload.getModels("openrouter").map((model) => model.id);
    JS

    assert_equal [MODEL_A, MODEL_B], result
  end

  def test_offline_cli_never_lists_the_unfiltered_catalog
    Dir.mktmpdir do |agent_dir|
      output, status = Open3.capture2e(
        {"OPENROUTER_API_KEY" => "review", "PI_CODING_AGENT_DIR" => agent_dir},
        "pi", "--no-extensions", "--extension", INDEX, "--offline", "--list-models", "openrouter"
      )

      assert status.success?, output
      assert_equal "No models matching \"openrouter\"\n", output
    end
  end

  private

  def command_available?(command)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
      File.executable?(File.join(directory, command))
    end
  end

  def run_runtime(body)
    install_root, status = Open3.capture2e("mise", "where", "npm:@earendil-works/pi-coding-agent")
    assert status.success?, install_root
    modules = File.join(install_root.strip, "node_modules/.mise/node_modules")
    script = runtime_bootstrap(modules, body)
    output, node_status = Open3.capture2e("node", "--no-warnings", "--input-type=module", "--eval", script)
    assert node_status.success?, output
    JSON.parse(output)
  end

  def runtime_bootstrap(modules, body)
    <<~JS
      import { createJiti } from #{File.join(modules, "jiti/lib/jiti.mjs").to_json};
      const aiPath = #{File.join(modules, "@earendil-works/pi-ai/dist").to_json};
      const agentPath = #{File.join(modules, "@earendil-works/pi-coding-agent/dist").to_json};
      const jiti = createJiti(`${agentPath}/index.js`, { alias: {
        "@earendil-works/pi-ai/providers/all": `${aiPath}/providers/all.js`,
        "@earendil-works/pi-ai": `${aiPath}/compat.js`,
        "@earendil-works/pi-coding-agent": `${agentPath}/index.js`
      }});
      const extension = await jiti.import(#{INDEX.to_json}, { default: true });
      const ai = await import(`${aiPath}/index.js`);
      process.env.OPENROUTER_API_KEY = "review";
      const makeProvider = () => {
        let provider;
        extension({ registerProvider(value) { provider = value; } });
        if (!provider || typeof provider !== "object") throw new Error("Extension did not register a native provider");
        return provider;
      };
      const run = async () => {
        #{body}
      };
      console.log(JSON.stringify(await run()));
    JS
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
