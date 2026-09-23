# standard:disable Dotfiles/BanFileSystemClasses -- black-box test requires isolated Pi state
require "test_helper"
require "open3"
require "tmpdir"

class MeridianProviderTest < Minitest::Test
  EXTENSION = File.expand_path("../../../files/home/.pi/agent/extensions/meridian.ts", __dir__)
  SUPPORTED_MODELS = %w[
    claude-fable-5
    claude-haiku-4-5-20251001
    claude-opus-4-6
    claude-opus-4-7
    claude-opus-4-8
    claude-opus-5
    claude-sonnet-4-6
  ].freeze

  def test_registers_distinct_provider_with_required_transport
    Dir.mktmpdir("meridian-provider") do |agent_dir|
      wrapper = File.join(agent_dir, "verify_meridian.ts")
      File.write(wrapper, <<~TS)
        import meridian from #{EXTENSION.to_json};

        export default function verify(pi) {
          let registered;
          meridian({ registerProvider: (id, config) => { registered = { id, config }; } });
          if (registered.id !== "meridian") throw new Error("wrong provider id");
          if (registered.config.baseUrl !== "http://127.0.0.1:3456") throw new Error("wrong base URL");
          if (registered.config.api !== "anthropic-messages") throw new Error("wrong API");
          if (registered.config.apiKey !== "x") throw new Error("wrong dummy key");
          if (registered.config.headers["x-meridian-agent"] !== "pi") throw new Error("missing Pi adapter header");
          if (registered.config.models.some((model) => model.provider !== "meridian")) throw new Error("wrong model provider");
          if (registered.config.models.some((model) => model.baseUrl !== registered.config.baseUrl)) throw new Error("wrong model URL");
          pi.registerProvider(registered.id, registered.config);
        }
      TS

      output, status = Open3.capture2e(
        {"PI_CODING_AGENT_DIR" => agent_dir, "PI_OFFLINE" => "1"},
        "pi", "--no-extensions", "--extension", wrapper, "--list-models", "meridian"
      )

      assert status.success?, output
      models = output.lines.filter_map { |line| line[/^meridian\s+(\S+)\s/, 1] }
      assert_equal SUPPORTED_MODELS, models.sort
      assert output.lines.all? { |line| !line.start_with?("anthropic ") }
    end
  end

  def test_does_not_replace_anthropic_provider
    Dir.mktmpdir("meridian-provider") do |agent_dir|
      output, status = Open3.capture2e(
        {"ANTHROPIC_API_KEY" => "test-key", "PI_CODING_AGENT_DIR" => agent_dir, "PI_OFFLINE" => "1"},
        "pi", "--no-extensions", "--extension", EXTENSION, "--list-models", "claude-opus-4-6"
      )

      assert status.success?, output
      assert_match(/^anthropic\s+claude-opus-4-6\s/, output)
      assert_match(/^meridian\s+claude-opus-4-6\s/, output)
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
