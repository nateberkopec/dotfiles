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
      FileUtils.mkdir_p(path)
      File.write("#{path}/herdr-plugin.toml", "[dotfiles_invalid_manifest\n")
      write_config(:herdr, "herdr_plugins" => [path])
      @fake_system.stub_file_content("#{path}/herdr-plugin.toml", "")
      step.run
      command = @fake_system.operations.find { |op, argv| op == :execute && argv.take(3) == %w[herdr plugin link] }[1]
      # Force offline validation in an isolated config; the invalid manifest
      # cannot be registered and we never contact the user's running server.
      env = {"HERDR_SOCKET_PATH" => "#{directory}/api.sock", "HERDR_CONFIG_PATH" => "#{directory}/config.toml"}
      output, status = Open3.capture2e(env, *command)
      refute status.success?
      assert_includes output, "TOML parse error"
      assert_includes output, "dotfiles_invalid_manifest"
      refute_includes output, "unknown option"
    end
    # standard:enable Dotfiles/BanFileSystemClasses
  rescue Errno::ENOENT
    flunk "Herdr is required for CLI contract coverage" if ENV["REQUIRE_HERDR"] == "1"
    skip "Herdr is not installed"
  end
end
