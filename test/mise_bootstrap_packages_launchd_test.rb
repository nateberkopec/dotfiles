require "test_helper"
require "toml-rb"

class MiseBootstrapPackagesLaunchdTest < Minitest::Test
  def test_declares_platform_package_managers
    packages = config.dig("bootstrap", "packages")

    assert_equal "latest", packages.fetch("brew:git")
    assert_equal "latest", packages.fetch("brew:terminal-notifier")
    assert_equal "latest", packages.fetch("apt:git")
    assert_equal "latest", packages.fetch("apt:yubikey-manager")
    assert_includes config.dig("bootstrap", "hooks", "post-packages"), "docker.io"
  end

  def test_declares_yknotify_launch_agent
    agent = config.dig("bootstrap", "macos", "launchd", "agents", "yknotify")

    assert_equal "~/.local/share/yknotify/yknotify.sh", agent.fetch("program")
    assert_equal true, agent.fetch("run_at_load")
    assert_equal true, agent.fetch("keep_alive")
    assert_equal "/tmp/yknotify.out", agent.fetch("stdout_path")
    assert_equal "/tmp/yknotify.err", agent.fetch("stderr_path")
  end

  def test_pins_bootstrap_tools
    tools = config.fetch("tools")

    assert_match(/\A\d+\.\d+\.\d+\z/, tools.fetch("ruby"))
    assert_match(/\A\d+\.\d+\.\d+\z/, tools.fetch("gum"))
  end

  private

  def config
    @config ||= TomlRB.load_file(File.expand_path("../files/home/.config/mise/config.toml", __dir__))
  end
end
