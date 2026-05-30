require "test_helper"

class ApplyPackageReleasePoliciesTest < Minitest::Test
  include SystemAssertions

  def test_applies_mise_and_homebrew_shell_policies_when_tools_are_available
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command("command -v fish >/dev/null 2>&1", "", exit_status: 0)

    migration.up

    assert_command_run(:execute, ["mise", "settings", "set", "minimum_release_age", "3d"], {quiet: true})
    assert_command_run(:execute, ["fish", "-c", "set -Ux HOMEBREW_AUTO_UPDATE_SECS 604800"], {quiet: true})
  end

  def test_skips_missing_tools
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 1)
    @fake_system.stub_command("command -v fish >/dev/null 2>&1", "", exit_status: 1)

    migration.up

    refute_command_run(:execute, ["mise", "settings", "set", "minimum_release_age", "3d"], {quiet: true})
    refute_command_run(:execute, ["fish", "-c", "set -Ux HOMEBREW_AUTO_UPDATE_SECS 604800"], {quiet: true})
  end

  private

  def migration
    Dotfiles::Migration::ApplyPackageReleasePolicies.new(
      debug: false,
      dotfiles_repo: "https://github.com/test/dotfiles.git",
      dotfiles_dir: @dotfiles_dir,
      home: @home,
      system: @fake_system
    )
  end
end
