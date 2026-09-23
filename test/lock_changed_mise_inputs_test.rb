require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

# Real git inputs exercise selection through the shell helper used by CI.
# standard:disable Dotfiles/BanFileSystemClasses
class LockChangedMiseInputsTest < Minitest::Test
  SOURCE = File.expand_path("../tools/ci", __dir__)

  def test_same_version_option_change_targets_only_that_tool
    with_repository do |root, base, config|
      File.write(config, omniwm("OmniWM-v{{version}}.zip"))
      File.write(File.join(root, "files/home/.config/mise/mise.lock"), "asset = \"new\"\n")

      output, status = run_helper(root, base)

      assert status.success?, output
      assert_equal [native_platform, "github:BarutSRB/OmniWM"], generated_arguments(root)
    end
  end

  def test_mise_generator_change_requests_a_full_refresh
    with_repository do |root, base, _config|
      File.write(File.join(root, "config/mise.version"), "2026.9.12\n")

      output, status = run_helper(root, base)

      assert status.success?, output
      assert_equal [native_platform, "--all"], generated_arguments(root)
    end
  end

  private

  def with_repository
    Dir.mktmpdir do |root|
      ci = File.join(root, "tools/ci")
      config_dir = File.join(root, "files/home/.config/mise")
      FileUtils.mkdir_p([ci, config_dir, File.join(root, "config")])
      %w[dependency_factory.rb lock_changed_mise_tools.sh mise_lock_targets.rb].each { |name| FileUtils.cp(File.join(SOURCE, name), ci) }
      FileUtils.cp_r(File.join(SOURCE, "dependency_factory"), ci)
      write_fake_generator(ci)
      config = File.join(config_dir, "config.toml")
      File.write(config, omniwm("old-{{version}}.zip"))
      File.write(File.join(config_dir, "mise.lock"), "asset = \"old\"\n")
      File.write(File.join(root, "config/mise.version"), "2026.9.4\n")
      git(root, "init", "--quiet")
      git(root, "add", ".")
      git(root, "commit", "--no-gpg-sign", "-qm", "Base")
      yield root, git(root, "rev-parse", "HEAD").first.strip, config
    end
  end

  def write_fake_generator(ci)
    File.write(File.join(ci, "lock_native_platform.sh"), <<~SH)
      #!/usr/bin/env bash
      printf '%s\n' "$@" > "$TARGET_LOG"
    SH
  end

  def run_helper(root, base)
    env = {"BUNDLE_GEMFILE" => File.expand_path("../Gemfile", __dir__), "TARGET_LOG" => File.join(root, "targets")}
    Open3.capture2e(env, "bash", File.join(root, "tools/ci/lock_changed_mise_tools.sh"), base, native_platform, chdir: root)
  end

  def generated_arguments(root)
    File.readlines(File.join(root, "targets"), chomp: true)
  end

  def omniwm(pattern)
    "[tools]\n\"github:BarutSRB/OmniWM\" = { version = \"0.6.9\", asset_pattern = \"#{pattern}\" }\n"
  end

  def native_platform
    os = RbConfig::CONFIG.fetch("host_os").match?(/darwin/) ? "macos" : "linux"
    arch = RbConfig::CONFIG.fetch("host_cpu").match?(/arm|aarch/) ? "arm64" : "x64"
    "#{os}-#{arch}"
  end

  def git(root, *args)
    Open3.capture2e("git", "-C", root, "-c", "core.hooksPath=/dev/null", "-c", "user.name=Test", "-c", "user.email=test@example.test", *args)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
