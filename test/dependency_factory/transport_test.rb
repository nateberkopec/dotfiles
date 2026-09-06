require "test_helper"
require "tmpdir"
require "open3"
require_relative "../../tools/ci/dependency_factory"

# Real git bundles verify the boundary between the checked and published commits.
# standard:disable Dotfiles/BanFileSystemClasses
class DependencyFactoryTransportTest < Minitest::Test
  def test_missing_branch_cannot_be_published
    assert_equal ["Publishing requires a branch"], DependencyFactory::Transport.errors({}, directory: "/tmp")
  end

  def test_missing_bundle_cannot_be_published
    Dir.mktmpdir do |root|
      assert_equal ["Missing queued bundle for test"], DependencyFactory::Transport.errors({"branch" => "test"}, directory: root)
    end
  end

  def test_only_the_commit_in_the_queued_bundle_can_be_reported
    Dir.mktmpdir do |root|
      git(root, "init", "-qb", "dependency-update-test")
      commit(root, "1.1")
      path = File.join(root, "aw-dependency-update-test.bundle")
      git(root, "bundle", "create", path, "dependency-update-test")
      item = {"branch" => "dependency-update-test"}
      assert_empty errors(item, root)

      commit(root, "1.2")
      assert_includes errors(item, root).join, "does not match the checked HEAD"
    end
  end

  def test_repo_qualified_bundle_takes_precedence_over_an_unqualified_one
    Dir.mktmpdir do |root|
      git(root, "init", "-qb", "dependency-update-test")
      commit(root, "1.1")
      git(root, "bundle", "create", File.join(root, "aw-owner-repo-dependency-update-test.bundle"), "dependency-update-test")
      commit(root, "1.2")
      git(root, "bundle", "create", File.join(root, "aw-dependency-update-test.bundle"), "dependency-update-test")
      assert_includes errors({"branch" => "dependency-update-test", "repo" => "Owner/Repo"}, root).join, "does not match the checked HEAD"
    end
  end

  private

  def errors(item, root)
    DependencyFactory::Transport.errors(item, directory: File.join(root, "agent"), root: root, repo: nil)
  end

  def commit(root, version)
    File.write(File.join(root, "pin"), version)
    git(root, "add", "pin")
    git(root, "commit", "--no-gpg-sign", "-qm", "Pin #{version}")
  end

  def git(root, *args)
    output, status = Open3.capture2e("git", "-C", root, "-c", "core.hooksPath=/dev/null", "-c", "user.name=Test", "-c", "user.email=test@example.test", *args)
    assert status.success?, output
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
