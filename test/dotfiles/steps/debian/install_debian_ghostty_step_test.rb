require "test_helper"

class InstallDebianGhosttyStepTest < StepTestCase
  step_class Dotfiles::Step::InstallDebianGhosttyStep

  def test_should_not_run_by_default
    refute_should_run
  end

  def test_complete_by_default
    assert_complete
  end

  def test_should_run_when_configured_and_missing
    @fake_system.stub_debian
    stub_ghostty_missing
    write_config("config", "debian_non_apt_packages" => ["ghostty"])

    assert_should_run
  end

  def test_incomplete_when_configured_and_missing
    @fake_system.stub_debian
    stub_ghostty_missing
    write_config("config", "debian_non_apt_packages" => ["ghostty"])

    assert_incomplete
  end

  def test_github_release_metadata_command_uses_token_without_leaking_value
    with_env("GITHUB_TOKEN" => "secret-token", "GH_TOKEN" => nil) do
      command = step.send(:github_release_metadata_command, "/tmp/ghostty-release.json")

      assert_includes command, "--retry 5"
      assert_includes command, "--retry-all-errors"
      assert_includes command, "Accept: application/vnd.github+json"
      assert_includes command, "Authorization: Bearer ${GITHUB_TOKEN}"
      refute_includes command, "secret-token"
    end
  end

  def test_github_release_metadata_command_uses_gh_token_fallback
    with_env("GITHUB_TOKEN" => nil, "GH_TOKEN" => "secret-token") do
      command = step.send(:github_release_metadata_command, "/tmp/ghostty-release.json")

      assert_includes command, "Authorization: Bearer ${GH_TOKEN}"
      refute_includes command, "secret-token"
    end
  end

  def test_appimage_download_command_uses_retries_without_auth_header
    command = step.send(:curl_download_command, "https://example.com/Ghostty.AppImage", "/tmp/ghostty.AppImage")

    assert_includes command, "curl -fsSL --retry 5"
    assert_includes command, "--retry-all-errors"
    refute_includes command, "Authorization:"
  end

  private

  def stub_ghostty_missing
    @fake_system.stub_command("command -v ghostty >/dev/null 2>&1", "", exit_status: 1)
  end
end
