# standard:disable Dotfiles/BanFileSystemClasses -- Pi needs a real isolated agent directory.
require "test_helper"
require "json"
require "open3"
require "tmpdir"

class DatasafeSubagentCatalogTest < Minitest::Test
  EXTENSION = File.expand_path("../../../files/home/.pi/agent/extensions/datasafe/index.ts", __dir__)
  KIMI = "accounts/fireworks/routers/kimi-k3-us"
  OLD = "accounts/fireworks/routers/old-us"
  ROUTER_OLD = "anthropic/claude-3-haiku"
  ROUTER_NEW = "google/gemini-2.5-pro"

  def test_running_session_refreshes_external_catalogs_before_subagent_launch
    Dir.mktmpdir("datasafe-subagent") do |dir|
      store = File.join(dir, "models-store.json")
      File.write(store, JSON.generate(catalog(OLD, ROUTER_OLD, 1)))
      probe = File.join(dir, "probe.ts")
      File.write(probe, <<~TS)
        import { refreshSubagentModels } from #{EXTENSION.to_json};
        export default function(pi) {
          pi.registerCommand("probe-registry", { handler: async (_args, ctx) => refreshSubagentModels(ctx) });
        }
      TS
      env = {"PI_CODING_AGENT_DIR" => dir, "PI_OFFLINE" => "1", "FIREWORKS_API_KEY" => "test-key",
             "OPENROUTER_API_KEY" => "test-key"}
      Open3.popen3(env, "pi", "--no-extensions", "--extension", EXTENSION, "--extension", probe,
        "--mode", "rpc", "--no-session") do |stdin, stdout, stderr, wait|
        begin
          assert_includes ids(stdin, stdout), OLD
          File.write(store, JSON.generate(catalog(KIMI, ROUTER_NEW, 2)))
          listing, errors, status = Open3.capture3(env, "pi", "--no-extensions", "--extension", EXTENSION,
            "--list-models", "kimi-k3-us")
          assert status.success?, errors
          assert_includes listing, KIMI
          refute_includes ids(stdin, stdout), KIMI, "the active registry is stale before the subagent preflight"

          stdin.puts JSON.generate(id: "refresh", type: "prompt", message: "/probe-registry")
          loop do
            reply = JSON.parse(stdout.gets || raise("Pi exited before refresh: #{stderr.read}"))
            next unless reply["id"] == "refresh"

            assert reply.fetch("success"), reply.inspect
            break
          end
          current = ids(stdin, stdout)
          assert_includes current, KIMI
          assert_includes current, ROUTER_NEW
          refute_includes current, OLD
          refute_includes current, ROUTER_OLD
        ensure
          stdin.close
          stdout.read
          stderr.read
        end
        assert wait.value.success?
      end
    end
  end

  private

  def ids(stdin, stdout)
    stdin.puts JSON.generate(id: "models", type: "get_available_models")
    loop do
      reply = JSON.parse(stdout.gets || raise("Pi exited without registry response"))
      return reply.fetch("data").fetch("models").map { |model| model.fetch("id") } if reply["id"] == "models"
    end
  end

  def catalog(fireworks_id, router_id, checked_at)
    {
      "fireworks" => {"models" => [{
        "id" => fireworks_id, "name" => fireworks_id, "provider" => "fireworks", "api" => "openai-completions",
        "baseUrl" => "https://us.api.fireworks.ai/inference/v1", "reasoning" => true, "input" => ["text"],
        "cost" => {"input" => 0, "output" => 0, "cacheRead" => 0, "cacheWrite" => 0},
        "contextWindow" => 200_000, "maxTokens" => 131_072
      }], "checkedAt" => checked_at},
      "openrouter" => {"models" => [{
        "id" => router_id, "name" => router_id, "provider" => "openrouter", "api" => "anthropic-messages",
        "baseUrl" => "https://us.openrouter.ai/api", "reasoning" => false, "input" => ["text"],
        "cost" => {"input" => 0, "output" => 0, "cacheRead" => 0, "cacheWrite" => 0},
        "contextWindow" => 200_000, "maxTokens" => 8192
      }], "checkedAt" => checked_at}
    }
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
