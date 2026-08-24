require "test_helper"
require "toml-rb"

class MiseBootstrapDotfilesDefaultsTest < Minitest::Test
  def test_declares_home_sync_templates_and_symlinks
    dotfiles = config.fetch("dotfiles")

    assert_equal({"source" => "~/.dotfiles/files/home", "mode" => "copy"}, dotfiles.fetch("~"))
    assert_equal "template", dotfiles.fetch("~/.config/fish/conf.d/platform.fish").fetch("mode")
    assert_equal "template", dotfiles.fetch("~/.config/ghostty/config.platform").fetch("mode")
    assert_equal "symlink", dotfiles.fetch("~/.local/bin/dotf").fetch("mode")
    assert_equal "copy", dotfiles.fetch("~/.local/share/yknotify/yknotify.sh").fetch("mode")
  end

  def test_declares_existing_fixed_macos_defaults
    defaults = config.dig("bootstrap", "macos", "defaults")

    assert_equal 0, defaults.dig("NSGlobalDomain", "NSAutomaticWindowAnimationsEnabled")
    assert_equal 2.0, defaults.dig("NSGlobalDomain", "com.apple.mouse.scaling")
    assert_equal "scale", defaults.dig("com.apple.dock", "mineffect")
    assert_equal 1, defaults.dig("com.apple.AppleMultitouchTrackpad", "TrackpadRightClick")
    assert_equal false, defaults.dig("com.apple.spaces", "spans-displays")
    assert_equal "Command-49", defaults.dig("com.raycast.macos", "raycastGlobalHotkey")
    assert_equal true, defaults.dig("com.raycast.macos", "onboarding_setupHotkey")
  end

  def test_installs_and_starts_omniwm
    tool = config.fetch("tools").fetch("github:BarutSRB/OmniWM")
    agent = config.dig("bootstrap", "macos", "launchd", "agents", "omniwm")

    assert_equal "OmniWM-v{{version}}.zip", tool.fetch("asset_pattern")
    assert_equal "~/.local/share/dotfiles/launch-omniwm", agent.fetch("program")
    assert_equal true, agent.fetch("run_at_load")
  end

  def test_wires_drift_hooks
    hooks = config.dig("bootstrap", "hooks")

    assert_includes hooks.fetch("post-dotfiles"), "post-dotfiles-hook.sh"
    assert_includes hooks.fetch("pre-defaults"), "pre-defaults-hook.sh"
    assert_includes hooks.fetch("post-defaults"), "post-defaults-hook.sh"
  end

  private

  def config
    @config ||= TomlRB.load_file(File.expand_path("../files/home/.config/mise/config.toml", __dir__))
  end
end
