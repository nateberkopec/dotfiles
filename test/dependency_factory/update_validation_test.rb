require "test_helper"
require "json"
require "open3"
require "tmpdir"
require "fileutils"

# Real git state exercises the mechanical checker before and after commits.
# standard:disable Dotfiles/BanFileSystemClasses
class DependencyFactoryUpdateValidationTest < Minitest::Test
  def test_uncommitted_npm_upgrade_is_allowed_when_git_sha_is_unchanged
    with_checkout do |root, base|
      write_settings(root, npm: "2.0.0")

      output, status = check(root, base)
      assert status.success?, output
    end
  end

  def test_git_reference_change_is_rejected
    with_checkout do |root, base|
      write_settings(root, git: "b" * 40)

      output, status = check(root, base)
      refute status.success?, output
      assert_includes output, "unsafe changes to files/home/.pi/agent/settings.json"
    end
  end

  private

  def with_checkout
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "files/home/.pi/agent"))
      write_settings(root)
      git(root, "init", "-q")
      git(root, "add", ".")
      git(root, "-c", "user.name=Test", "-c", "user.email=test@example.test", "commit", "--no-gpg-sign", "-qm", "Fixture")
      yield root, git(root, "rev-parse", "HEAD").strip
    end
  end

  def write_settings(root, npm: "1.0.0", git: "a" * 40)
    path = File.join(root, "files/home/.pi/agent/settings.json")
    File.write(path, JSON.generate("packages" => ["npm:test-package@#{npm}", "git:github.com/example/plugin@#{git}"]))
  end

  def check(root, base)
    script = File.expand_path("../../tools/ci/check_dependency_update.rb", __dir__)
    gemfile = File.expand_path("../../Gemfile", __dir__)
    Open3.capture2e({"BUNDLE_GEMFILE" => gemfile}, "bundle", "exec", "ruby", script, base, chdir: root)
  end

  def git(root, *args)
    output, status = Open3.capture2e("git", "-C", root, "-c", "core.hooksPath=/dev/null", *args)
    assert status.success?, output
    output
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
