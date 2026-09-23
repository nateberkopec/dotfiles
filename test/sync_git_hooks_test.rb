# standard:disable Dotfiles/BanFileSystemClasses -- black-box script test requires real temporary files
require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class SyncGitHooksTest < Minitest::Test
  SCRIPT = File.expand_path("../bin/lib/sync-git-hooks.sh", __dir__)

  def test_syncs_hooks_when_target_is_writable
    with_hook_directories do |home, source, target|
      File.write(File.join(source, "pre-commit"), "managed\n")
      FileUtils.chmod(0o755, File.join(source, "pre-commit"))

      _stdout, stderr, status = Open3.capture3({"HOME" => home}, "bash", SCRIPT)

      assert status.success?, stderr
      assert_equal "managed\n", File.read(File.join(target, "pre-commit"))
      assert File.executable?(File.join(target, "pre-commit"))
    end
  end

  def test_preserves_externally_managed_hooks_when_target_is_read_only
    with_hook_directories do |home, source, target|
      File.write(File.join(source, "pre-commit"), "managed\n")
      File.write(File.join(target, "pre-commit"), "external\n")
      FileUtils.chmod(0o555, target)

      _stdout, stderr, status = Open3.capture3({"HOME" => home}, "bash", SCRIPT)

      assert status.success?, stderr
      assert_equal "external\n", File.read(File.join(target, "pre-commit"))
      assert_includes stderr, "skipping git hook sync; #{target} is not writable"
    ensure
      FileUtils.chmod(0o755, target)
    end
  end

  private

  def with_hook_directories
    Dir.mktmpdir do |dir|
      home = File.join(dir, "home")
      source = File.join(home, ".dotfiles/files/home/.git-hooks")
      target = File.join(home, ".git-hooks")
      FileUtils.mkdir_p([source, target])
      yield home, source, target
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
