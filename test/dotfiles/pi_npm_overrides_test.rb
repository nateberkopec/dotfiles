require "test_helper"

class PiNpmOverridesTest < Minitest::Test
  def setup
    @system = FakeSystemAdapter.new
    @agent = "/home/test/.pi/agent"
    @overrides = Dotfiles::PiNpmOverrides.new(home: "/home/test", system: @system)
  end

  def test_no_configuration_leaves_manifest_untouched
    assert @overrides.current?
    @overrides.apply
    refute @system.file_exist?(File.join(@agent, "npm", "package.json"))
  end

  def test_apply_preserves_dependencies_and_unrelated_overrides
    configure
    manifest = {"dependencies" => {"pi-mcp-adapter" => "4.0.0"}, "overrides" => {"other" => "1.0.0"}}
    @system.stub_file_content(File.join(@agent, "npm", "package.json"), JSON.generate(manifest))

    @overrides.apply

    updated = JSON.parse(@system.read_file(File.join(@agent, "npm", "package.json")))
    assert_equal manifest["dependencies"], updated["dependencies"]
    assert_equal({"other" => "1.0.0", "@modelcontextprotocol/client" => "2.2.0"}, updated["overrides"])
    assert_equal ["@modelcontextprotocol/client"], @overrides.release_age_exclusions
  end

  def test_patched_hoisted_version_does_not_hide_vulnerable_nested_version
    configure
    @overrides.apply
    package("@modelcontextprotocol/client", "2.2.0")
    package("pi-mcp-adapter/node_modules/@modelcontextprotocol/client", "2.0.0")

    refute @overrides.current?

    package("pi-mcp-adapter/node_modules/@modelcontextprotocol/client", "2.2.0")
    assert @overrides.current?
  end

  def test_override_without_installed_dependency_is_not_complete
    configure
    @overrides.apply
    refute @overrides.current?
  end

  private

  def configure
    @system.stub_file_content(File.join(@agent, "npm-overrides.json"), '{"@modelcontextprotocol/client":"2.2.0"}')
  end

  def package(name, version)
    @system.stub_file_content(File.join(@agent, "npm", "node_modules", name, "package.json"), JSON.generate("version" => version))
  end
end
