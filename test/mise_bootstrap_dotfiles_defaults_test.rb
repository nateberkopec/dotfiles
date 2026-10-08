require "test_helper"
require "toml-rb"

class MiseBootstrapDotfilesDefaultsTest < Minitest::Test
  def test_declares_home_sync_templates_and_symlinks
    dotfiles = config.fetch("dotfiles")

    assert_equal(
      {"source" => "~/.dotfiles/files/home", "mode" => "copy", "exclude" => [".git-hooks", ".agents/skills"]},
      dotfiles.fetch("~")
    )
    assert_equal "template", dotfiles.fetch("~/.config/fish/conf.d/platform.fish").fetch("mode")
    assert_equal "template", dotfiles.fetch("~/.config/ghostty/config.platform").fetch("mode")
    assert_equal "symlink", dotfiles.fetch("~/.local/bin/dotf").fetch("mode")
    assert_equal "copy", dotfiles.fetch("~/.local/share/yknotify/yknotify.sh").fetch("mode")
  end

  def test_exports_noninteractive_bash_safety_setup
    assert_equal "{{env.HOME}}/.config/bash/safety.bash", config.fetch("env").fetch("BASH_ENV")
  end

  def test_declares_existing_fixed_macos_defaults
    defaults = config.dig("bootstrap", "macos", "defaults")

    assert_equal 0, defaults.dig("NSGlobalDomain", "NSAutomaticWindowAnimationsEnabled")
    assert_equal 2.0, defaults.dig("NSGlobalDomain", "com.apple.mouse.scaling")
    assert_equal true, defaults.dig("com.apple.dock", "autohide")
    assert_equal "left", defaults.dig("com.apple.dock", "orientation")
    assert_equal "scale", defaults.dig("com.apple.dock", "mineffect")
    assert_equal 1, defaults.dig("com.apple.AppleMultitouchTrackpad", "TrackpadRightClick")
    assert_equal false, defaults.dig("com.apple.spaces", "spans-displays")
    refute defaults.key?("com.raycast.macos")
  end

  def test_builds_native_try_with_pinned_spinel_backend
    tool = config.fetch("tools").fetch("spinel:tobi/try")

    assert_match %r{\Ahttps://github\.com/nateberkopec/mise-backend-spinel#[0-9a-f]{40}\z}, config.fetch("plugins").fetch("spinel")
    assert_equal "1.10.1", tool.fetch("version")
    assert_equal "try", tool.fetch("bin")
    assert_equal "try.rb", tool.fetch("entrypoint")
    assert_equal "be566829856ca6bd22963e38a28ffb5efa24c7de", tool.fetch("source_ref")
    assert_equal "1c84866b3acaaa6c568c3f239d3f4836f43c5bbb", tool.fetch("spinel_ref")
  end

  def test_installs_native_tinycast_release
    tool = config.fetch("tools").fetch("github:abue-ammar/tinycast")

    assert_equal "0.11.3", tool.fetch("version")
    assert_equal "Tinycast-{{version}}.zip", tool.fetch("asset_pattern")
    assert_equal "Tinycast.app/Contents/MacOS", tool.fetch("bin_path")
    assert_equal ["macos"], tool.fetch("os")
    assert_equal ["arm64"], tool.fetch("arch")
  end

  def test_installs_native_codexbar_release
    tool = config.fetch("tools").fetch("github:steipete/CodexBar")

    assert_equal "0.70.0", tool.fetch("version")
    assert_equal "CodexBar-macos-universal-{{version}}.zip", tool.fetch("asset_pattern")
    assert_equal "CodexBar.app/Contents/MacOS", tool.fetch("bin_path")
    assert_equal ["macos"], tool.fetch("os")
  end

  def test_installs_and_starts_omniwm_only_in_admin_environment
    refute config.fetch("tools").key?("github:BarutSRB/OmniWM")
    refute config.dig("bootstrap", "macos", "launchd", "agents").key?("omniwm")

    admin_config = TomlRB.load_file(File.expand_path("../files/home/.config/mise/config.admin.toml", __dir__))
    admin_lock = TomlRB.load_file(File.expand_path("../files/home/.config/mise/mise.admin.lock", __dir__))
    tool = admin_config.fetch("tools").fetch("github:BarutSRB/OmniWM")
    agent = admin_config.dig("bootstrap", "macos", "launchd", "agents", "omniwm")

    assert_equal "OmniWM-v{{version}}.zip", tool.fetch("asset_pattern")
    assert_equal tool.fetch("version"), admin_lock.fetch("tools").fetch("github:BarutSRB/OmniWM").first.fetch("version")
    assert_equal "~/.local/share/dotfiles/launch-omniwm", agent.fetch("program")
    assert_equal true, agent.fetch("run_at_load")
  end

  def test_wires_drift_hooks
    hooks = config.dig("bootstrap", "hooks")

    assert_includes hooks.fetch("pre-dotfiles"), "unprotect-managed-files.sh"
    assert_includes hooks.fetch("post-dotfiles"), "post-dotfiles-hook.sh"
    assert_includes hooks.fetch("pre-defaults"), "pre-defaults-hook.sh"
    assert_includes hooks.fetch("post-defaults"), "post-defaults-hook.sh"
  end

  private

  def config
    @config ||= TomlRB.load_file(File.expand_path("../files/home/.config/mise/config.toml", __dir__))
  end
end
