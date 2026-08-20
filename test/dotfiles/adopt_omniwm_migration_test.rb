require "test_helper"

class AdoptOmniWMMigrationTest < Minitest::Test
  include SystemAssertions

  def test_removes_aerospace_and_homebrew_omniwm
    prepare_migration

    migration.up

    %w[aerospace omniwm].each do |cask|
      assert_executed!(brew_command("uninstall", "--cask", cask))
    end
    %w[nikitabobko/tap barutsrb/tap].each do |tap|
      assert_executed!(brew_command("untap", tap))
    end
    retired_paths.each { |path| refute @fake_system.file_exist?(path) }
  end

  def test_replaces_login_items_with_the_mise_launch_agent
    prepare_migration

    migration.up

    assert_executed!(stop_command)
    assert_executed!(login_items_command)
    assert_executed!(start_command)
  end

  def test_is_idempotent_when_homebrew_installs_are_absent
    @fake_system.stub_macos
    @fake_system.stub_command(brew_exists_command, "", exit_status: 0)
    %w[aerospace omniwm].each do |cask|
      @fake_system.stub_command(brew_command("list", "--cask", cask), "", exit_status: 1)
    end
    %w[nikitabobko/tap barutsrb/tap].each do |tap|
      @fake_system.stub_command(tap_installed_command(tap), "", exit_status: 1)
    end

    migration.up
    migration.up

    refute @fake_system.received_operation?(
      :execute!, brew_command("uninstall", "--cask", "aerospace"), {quiet: true}
    )
    refute @fake_system.received_operation?(
      :execute!, brew_command("untap", "barutsrb/tap"), {quiet: true}
    )
  end

  private

  def prepare_migration
    @fake_system.stub_macos
    retired_paths.each { |path| @fake_system.stub_file_content(path, "old") }
    @fake_system.stub_command(brew_exists_command, "", exit_status: 0)
    %w[aerospace omniwm].each do |cask|
      @fake_system.stub_command(brew_command("list", "--cask", cask), cask, exit_status: 0)
    end
    %w[nikitabobko/tap barutsrb/tap].each do |tap|
      @fake_system.stub_command(tap_installed_command(tap), tap, exit_status: 0)
    end
  end

  def migration
    Dotfiles::Migration::AdoptOmniWM.new(
      dotfiles_dir: @dotfiles_dir,
      home: @home,
      system: @fake_system
    )
  end

  def retired_paths
    Dotfiles::Migration::AdoptOmniWM::RETIRED_PATHS.map { |path| File.join(@home, path) }
  end

  def brew_exists_command
    ["bash", "-c", 'command -v -- "$1" >/dev/null 2>&1', "dotfiles", "brew"]
  end

  def brew_command(*args)
    [{"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", *args]
  end

  def tap_installed_command(tap)
    [
      "bash", "-c",
      'env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew tap | grep -Fqx -- "$1"',
      "dotfiles", tap
    ]
  end

  def stop_command
    ["bash", "-c", "pkill -x AeroSpace 2>/dev/null || true; pkill -x OmniWM 2>/dev/null || true", "dotfiles"]
  end

  def login_items_command
    [
      "osascript",
      "-e", 'tell application "System Events"',
      "-e", 'if exists login item "AeroSpace" then delete login item "AeroSpace"',
      "-e", 'if exists login item "OmniWM" then delete login item "OmniWM"',
      "-e", "end tell"
    ]
  end

  def start_command
    ["bash", "-c", 'launchctl kickstart -k "gui/$(id -u)/dev.mise.omniwm"', "dotfiles"]
  end
end
