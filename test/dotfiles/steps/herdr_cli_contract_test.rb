require "test_helper"
require "open3"
require "tmpdir"

class HerdrCliContractTest < StepTestCase
  step_class Dotfiles::Step::LinkHerdrPluginsStep

  def test_generated_command_reaches_real_herdr_manifest_validation
    _output, installed = Open3.capture2e("herdr", "--version")
    unless installed.success?
      flunk "Herdr is required for CLI contract coverage" if ENV["REQUIRE_HERDR"] == "1"
      skip "Herdr is not installed"
    end

    # standard:disable Dotfiles/BanFileSystemClasses
    Dir.mktmpdir("dotfiles-herdr-") do |directory|
      # Include spaces to exercise argv handling as well as option order.
      path = "#{directory}/plugin with spaces"
      write_config(:herdr, "herdr_plugins" => [path])
      @fake_system.stub_file_content("#{path}/herdr-plugin.toml", "")
      step.run
      command = @fake_system.operations.find { |op, argv| op == :execute && argv.first == "herdr" }[1]
      # No real manifest: validate parsing without registering a plugin or
      # contacting the user's running Herdr server.
      output, status = Open3.capture2e(*command)
      refute status.success?
      assert_includes output, "plugin_manifest_not_found"
      refute_includes output, "unknown option"
    end
    # standard:enable Dotfiles/BanFileSystemClasses
  rescue Errno::ENOENT
    flunk "Herdr is required for CLI contract coverage" if ENV["REQUIRE_HERDR"] == "1"
    skip "Herdr is not installed"
  end
end
