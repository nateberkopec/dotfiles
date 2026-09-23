require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

# Real git fixtures exercise the target-selection CLI at its process boundary.
# standard:disable Dotfiles/BanFileSystemClasses
class DependencyFactoryMiseLockTargetsTest < Minitest::Test
  def test_selects_only_changed_tools_despite_unrelated_omniwm_lock_drift
    Dir.mktmpdir do |root|
      config = File.join(root, "files/home/.config/mise")
      FileUtils.mkdir_p(config)
      File.write(File.join(config, "config.toml"), pins(gh: "2.99.0"))
      git(root, "init", "--quiet")
      git(root, "add", ".")
      git(root, "commit", "--no-gpg-sign", "-qm", "Base")
      base = git(root, "rev-parse", "HEAD").first.strip

      File.write(File.join(config, "config.toml"), pins(gh: "2.100.0"))
      File.write(File.join(config, "mise.lock"), "url = \"https://github.com/OmniNull/OmniWM/releases/download/v0.6.9/OmniWM.zip\"\n")

      output, status = Open3.capture2e({"BUNDLE_GEMFILE" => File.expand_path("../../Gemfile", __dir__)}, "bundle", "exec", "ruby", script, base, chdir: root)

      assert status.success?, output
      assert_equal "gh\n", output
    end
  end

  def test_rejects_lock_drift_without_a_changed_pin
    Dir.mktmpdir do |root|
      config = File.join(root, "files/home/.config/mise")
      FileUtils.mkdir_p(config)
      File.write(File.join(config, "config.toml"), pins(gh: "2.99.0"))
      File.write(File.join(config, "mise.lock"), "owner = \"BarutSRB\"\n")
      git(root, "init", "--quiet")
      git(root, "add", ".")
      git(root, "commit", "--no-gpg-sign", "-qm", "Base")
      base = git(root, "rev-parse", "HEAD").first.strip
      File.write(File.join(config, "mise.lock"), "owner = \"OmniNull\"\n")

      output, status = Open3.capture2e({"BUNDLE_GEMFILE" => File.expand_path("../../Gemfile", __dir__)}, "bundle", "exec", "ruby", script, base, chdir: root)

      refute status.success?
      assert_includes output, "mise.lock changed without a corresponding global mise pin"
    end
  end

  def test_requests_an_explicit_full_refresh_when_a_tool_was_removed
    Dir.mktmpdir do |root|
      config = File.join(root, "files/home/.config/mise")
      FileUtils.mkdir_p(config)
      File.write(File.join(config, "config.toml"), pins(gh: "2.99.0"))
      git(root, "init", "--quiet")
      git(root, "add", ".")
      git(root, "commit", "--no-gpg-sign", "-qm", "Base")
      base = git(root, "rev-parse", "HEAD").first.strip
      File.write(File.join(config, "config.toml"), "[tools]\n")

      output, status = Open3.capture2e({"BUNDLE_GEMFILE" => File.expand_path("../../Gemfile", __dir__)}, "bundle", "exec", "ruby", script, base, chdir: root)

      assert status.success?, output
      assert_equal "--all\n", output
    end
  end

  private

  def pins(gh:)
    "[tools]\ngh = \"#{gh}\"\n\"github:BarutSRB/OmniWM\" = \"0.6.9\"\n"
  end

  def script
    File.expand_path("../../tools/ci/mise_lock_targets.rb", __dir__)
  end

  def git(root, *args)
    Open3.capture2e("git", "-C", root, "-c", "core.hooksPath=/dev/null", "-c", "user.name=Test", "-c", "user.email=test@example.test", *args)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
