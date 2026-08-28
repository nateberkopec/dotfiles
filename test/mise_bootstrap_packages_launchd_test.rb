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

  def test_declares_daily_wallpaper_launch_agent
    agent = config.dig("bootstrap", "macos", "launchd", "agents", "woodblock-wallpaper")

    assert_equal "~/.local/share/dotfiles/launch-woodblock-wallpaper", agent.fetch("program")
    assert_equal({"PATH" => "/usr/bin:/bin"}, agent.fetch("environment"))
    refute agent.key?("args")
    assert_equal true, agent.fetch("run_at_load")
    assert_equal({"hour" => 5, "minute" => 0}, agent.fetch("start_calendar_interval"))
    assert_equal true, agent.fetch("kickstart")
    assert_equal "~/Library/Logs/woodblock-wallpaper.out.log", agent.fetch("stdout_path")
    assert_equal "~/Library/Logs/woodblock-wallpaper.err.log", agent.fetch("stderr_path")
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
    assert_match(/\A\d+\.\d+\.\d+\z/, tools.fetch("pipx"))
    assert_match(/\A\d+\.\d+\.\d+\z/, tools.dig("pipx:playwright", "version"))
    assert_equal ["pipx"], tools.dig("pipx:playwright", "depends")
  end

  def test_preinstalls_playwright_headless_shell
    hook_path = File.expand_path("../bin/lib/post-dotfiles-hook.sh", __dir__)
    hook = Dotfiles::SystemAdapter.new.read_file(hook_path)

    assert_includes hook, "mise exec -- playwright install chromium-headless-shell"
  end

  private

  def config
    @config ||= TomlRB.load_file(File.expand_path("../files/home/.config/mise/config.toml", __dir__))
  end
end
