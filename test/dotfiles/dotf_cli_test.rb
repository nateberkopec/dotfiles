require "test_helper"

# standard:disable Dotfiles/BanFileSystemClasses
class DotfCliTest < Minitest::Test
  def test_init_logging_keeps_only_last_thirty_dotf_logs
    with_dotf_script do |tmpdir, script_path, logs_dir|
      seed_dotf_logs(logs_dir)
      log_file_record = File.join(tmpdir, "log-file-path")
      source_script_and_init_logging(script_path, log_file_record)
      assert_last_thirty_logs_remain(logs_dir)
      assert File.exist?(File.read(log_file_record).chomp)
    end
  end

  def test_every_dotf_invocation_rotates_logs
    with_dotf_script do |_tmpdir, script_path, logs_dir|
      seed_dotf_logs(logs_dir)
      assert system("bash", script_path, "help", out: File::NULL)
      assert_last_thirty_logs_remain(logs_dir, removed: ["dotf_2000-01-01_00-00-00.log"])
    end
  end

  def test_upgrade_updates_pi_extensions
    assert_upgrade_commands(
      stubs: %w[mise brew pi],
      env: {"DOTF_FORCE_NON_DEBIAN" => "true"},
      expected: [
        "brew shellenv bash", "mise activate bash", "mise cache clear --yes", "mise plugins update",
        "mise up --dry-run --minimum-release-age 3d --yes",
        "mise up --minimum-release-age 3d --yes",
        "mise install --minimum-release-age 3d --yes", "pi update --extensions",
        "mise prune --yes", "mise cache prune --yes",
        "HOMEBREW_AUTO_UPDATE_SECS=604800 brew upgrade",
        "HOMEBREW_AUTO_UPDATE_SECS=604800 brew autoremove",
        "HOMEBREW_AUTO_UPDATE_SECS=604800 brew cleanup"
      ]
    )
  end

  def test_upgrade_runs_on_debian_without_homebrew
    assert_upgrade_commands(
      stubs: %w[mise apt-get],
      env: {"DOTF_FORCE_DEBIAN" => "true", "DOTF_SKIP_SUDO" => "true"},
      expected: [
        "mise activate bash", "mise cache clear --yes", "mise plugins update",
        "mise up --dry-run --minimum-release-age 3d --yes",
        "mise up --minimum-release-age 3d --yes",
        "mise install --minimum-release-age 3d --yes", "mise prune --yes", "mise cache prune --yes",
        "apt-get update -y", "apt-get upgrade -y", "apt-get autoremove -y", "apt-get clean"
      ]
    )
  end

  private

  def assert_upgrade_commands(stubs:, expected:, env: {})
    with_dotf_script do |tmpdir, script_path, _logs_dir|
      bin_dir = File.join(tmpdir, "fake-bin")
      log_path = File.join(tmpdir, "upgrade-commands.log")
      FileUtils.mkdir_p(bin_dir)
      stubs.each { |command| write_command_stub(bin_dir, command) }

      with_env(env.merge("DOTF_UPGRADE_LOG" => log_path, "PATH" => "#{bin_dir}:/usr/bin:/bin")) do
        assert system("bash", script_path, "upgrade", out: File::NULL)
      end

      assert_equal expected, File.readlines(log_path, chomp: true)
    end
  end

  def assert_last_thirty_logs_remain(logs_dir, removed: ["dotf_2000-01-01_00-00-00.log", "dotf_2000-01-01_00-00-01.log"])
    dotf_logs = current_dotf_logs(logs_dir)
    assert_equal 30, dotf_logs.size
    removed.each { |log| refute_includes dotf_logs, log }
    assert_includes dotf_logs, "dotf_2000-01-01_00-00-30.log"
    assert File.exist?(File.join(logs_dir, "other.log"))
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
