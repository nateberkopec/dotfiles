require "test_helper"

class InstallPiPackagesStepTest < StepTestCase
  step_class Dotfiles::Step::InstallPiPackagesStep

  def test_has_no_step_dependencies
    assert_empty self.class.step_class.depends_on
  end

  def test_should_not_run_by_default
    refute_should_run
  end

  def test_should_run_when_pinned_package_is_missing
    stub_settings('{"packages":["npm:pi-ding@0.2.2"]}')
    stub_pi_available
    stub_pi_list("")

    assert_should_run
  end

  def test_should_not_run_when_pinned_package_is_installed
    stub_settings('{"packages":["npm:pi-ding@0.2.2"]}')
    stub_pi_available
    stub_installed_npm_package("pi-ding", "0.2.2")

    refute_should_run
    refute_executed("pi list")
  end

  def test_should_run_when_installed_npm_package_does_not_match_pin
    stub_settings('{"packages":["npm:pi-subagents@0.34.0"]}')
    stub_pi_available
    stub_pi_list("User packages:\n  npm:pi-subagents@0.34.0\n")
    stub_installed_npm_package("pi-subagents", "0.25.0")

    assert_should_run
  end

  def test_run_installs_missing_pinned_package
    stub_settings('{"packages":["npm:pi-ding@0.2.2"]}')
    stub_pi_available
    stub_pi_list("")
    @fake_system.stub_command("pi install npm:pi-ding@0.2.2", "")

    step.run

    assert_executed("pi install npm:pi-ding@0.2.2")
  end

  def test_complete_reports_missing_pi
    stub_settings('{"packages":["npm:pi-ding@0.2.2"]}')
    @fake_system.stub_command("command -v pi >/dev/null 2>&1", "", exit_status: 1)

    assert_incomplete
  end

  def test_complete_by_default
    assert_complete
  end

  def test_run_without_settings_does_not_invoke_pi
    step.run

    refute_executed("pi list")
  end

  def test_git_packages_share_a_list_and_refresh_after_installation
    packages = ["git:github.com/example/one@abc", "git:github.com/example/two@def"]
    stub_settings(JSON.generate("packages" => packages))
    stub_pi_available
    stub_pi_list("")

    assert_should_run
    step.run
    packages.each { |package| assert_executed("pi install #{package}") }
    stub_pi_list(packages.join("\n"))
    assert_complete

    calls = @fake_system.operations.count { |operation, cmd| operation == :execute && cmd == ["pi", "list"] }
    assert_equal 3, calls
  end

  def test_filtered_git_package_installs_source_and_preserves_filters
    package = {"source" => "git:github.com/mitsuhiko/agent-stuff@#{"a" * 40}", "extensions" => ["extensions/goal.ts"], "skills" => []}
    settings = JSON.generate("packages" => [package])
    stub_settings(settings)
    stub_pi_available
    stub_pi_list("")

    assert_should_run
    step.run
    assert_executed("pi install #{package.fetch("source")}")
    stub_pi_list("User packages:\n  #{package.fetch("source")} (filtered)\n    /home/test/.pi/agent/git/github.com/mitsuhiko/agent-stuff\n")
    assert_complete
    assert_equal settings, @fake_system.read_file(File.join(@home, ".pi", "agent", "settings.json"))
  end

  def test_unpinned_npm_package_still_uses_pi_list
    stub_settings('{"packages":["npm:example"]}')
    stub_pi_available
    stub_pi_list("npm:example")

    refute_should_run
    assert_executed("pi list")
  end

  def test_failed_list_cannot_reuse_a_previous_successful_snapshot
    package = "git:github.com/example/one@abc"
    stub_settings(JSON.generate("packages" => [package]))
    stub_pi_available
    stub_pi_list(package)
    assert_complete
    @fake_system.stub_command("pi list", "list failed", exit_status: 1)

    assert_incomplete
    assert_includes step.errors.join("\n"), package
  end

  def test_installed_adapter_is_reinstalled_when_sdk_is_vulnerable
    stub_settings('{"packages":["npm:pi-mcp-adapter@4.0.0"]}')
    stub_pi_available
    stub_installed_npm_package("pi-mcp-adapter", "4.0.0")
    @fake_system.stub_file_content(File.join(@home, ".pi", "agent", "npm-overrides.json"), '{"@modelcontextprotocol/client":"2.2.0"}')
    stub_installed_npm_package("@modelcontextprotocol/client", "2.0.0")

    assert_should_run
    step.run

    assert_executed("npm_config_min_release_age_exclude=@modelcontextprotocol/client pi install npm:pi-mcp-adapter@4.0.0")
    manifest = JSON.parse(@fake_system.read_file(File.join(@home, ".pi", "agent", "npm", "package.json")))
    assert_equal({"@modelcontextprotocol/client" => "2.2.0"}, manifest.fetch("overrides"))
    assert_incomplete
    stub_installed_npm_package("pi-mcp-adapter", "4.0.0")
    stub_installed_npm_package("@modelcontextprotocol/client", "2.2.0")
    assert_complete
    refute_should_run
  end

  def test_overrides_are_applied_before_pi_list_can_install_packages
    stub_settings('{"packages":["git:github.com/example/one@abc"]}')
    stub_pi_available
    @fake_system.stub_file_content(File.join(@home, ".pi", "agent", "npm-overrides.json"), '{"@modelcontextprotocol/client":"2.2.0"}')

    step.should_run?

    operations = @fake_system.operations
    write = operations.index { |operation| operation[0] == :write_file && operation[1].end_with?("npm/package.json") }
    list = operations.index { |operation| operation[0] == :execute && operation[1].join(" ").end_with?("pi list") }
    assert_operator write, :<, list
    assert_executed("npm_config_min_release_age_exclude=@modelcontextprotocol/client pi list")
  end

  def test_invalid_sdk_metadata_fails_closed
    stub_settings('{"packages":["npm:pi-mcp-adapter@4.0.0"]}')
    stub_pi_available
    stub_installed_npm_package("pi-mcp-adapter", "4.0.0")
    @fake_system.stub_file_content(File.join(@home, ".pi", "agent", "npm-overrides.json"), '{"@modelcontextprotocol/client":"2.2.0"}')
    @fake_system.stub_file_content(File.join(@home, ".pi", "agent", "npm", "package.json"), '{"overrides":{"@modelcontextprotocol/client":"2.2.0"}}')
    @fake_system.stub_file_content(File.join(@home, ".pi", "agent", "npm", "node_modules", "@modelcontextprotocol/client", "package.json"), "broken")

    assert_raises(JSON::ParserError) { step.should_run? }
  end

  private

  def stub_settings(content)
    @fake_system.stub_file_content(File.join(@home, ".pi", "agent", "settings.json"), content)
  end

  def stub_pi_available
    @fake_system.stub_command("command -v pi >/dev/null 2>&1", "", exit_status: 0)
  end

  def stub_pi_list(output)
    @fake_system.stub_command("pi list", output)
  end

  def stub_installed_npm_package(name, version)
    path = File.join(@home, ".pi", "agent", "npm", "node_modules", name, "package.json")
    @fake_system.stub_file_content(path, JSON.generate("version" => version))
  end
end
