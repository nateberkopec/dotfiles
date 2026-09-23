require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

# The fake mise boundary verifies selection without touching the real lock.
# standard:disable Dotfiles/BanFileSystemClasses
class LockNativePlatformTest < Minitest::Test
  def test_passes_only_selected_tools_and_preserves_unrelated_omniwm
    with_fake_mise do |home, log, platform|
      output, status = run_script(home, platform, "gh")

      assert status.success?, output
      assert_equal ["lock", "--global", "--platform", platform, "gh"], File.readlines(log, chomp: true)
      refute_includes File.read(log), "OmniWM"
    end
  end

  def test_requires_an_explicit_selection
    with_fake_mise do |home, _log, platform|
      output, status = run_script(home, platform)

      refute status.success?
      assert_includes output, "Specify changed tools, or --all"
    end
  end

  def test_allows_an_explicit_full_refresh
    with_fake_mise do |home, log, platform|
      output, status = run_script(home, platform, "--all")

      assert status.success?, output
      assert_equal ["lock", "--global", "--platform", platform], File.readlines(log, chomp: true)
    end
  end

  private

  def with_fake_mise
    Dir.mktmpdir do |home|
      bin = File.join(home, ".local/bin")
      FileUtils.mkdir_p(bin)
      fake = File.join(bin, "mise")
      File.write(fake, <<~SH)
        #!/usr/bin/env bash
        if [ "$1" = "--version" ]; then
          cat "#{File.expand_path("../config/mise.version", __dir__)}"
        else
          printf '%s\n' "$@" > "$ARG_LOG"
        fi
      SH
      FileUtils.chmod("+x", fake)
      yield home, File.join(home, "args"), native_platform
    end
  end

  def native_platform
    os = RbConfig::CONFIG.fetch("host_os").match?(/darwin/) ? "macos" : "linux"
    arch = RbConfig::CONFIG.fetch("host_cpu").match?(/arm|aarch/) ? "arm64" : "x64"
    "#{os}-#{arch}"
  end

  def run_script(home, *arguments)
    env = {"HOME" => home, "ARG_LOG" => File.join(home, "args")}
    Open3.capture2e(env, "bash", File.expand_path("../tools/ci/lock_native_platform.sh", __dir__), *arguments)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
