require "test_helper"
require "tmpdir"
require_relative "../../tools/ci/dependency_factory"

# standard:disable Dotfiles/BanFileSystemClasses
class DependencyFactoryTransportTest < Minitest::Test
  def test_missing_bundle_has_no_publication_path
    Dir.mktmpdir do |root|
      assert_nil DependencyFactory::Transport.queued_bundle({"branch" => "test"}, directory: root, repo: "owner/repo")
    end
  end

  def test_qualified_bundle_can_be_resolved_when_repo_is_omitted
    Dir.mktmpdir do |root|
      directory = File.join(root, "agent")
      path = File.join(root, "aw-owner-repo-test.bundle")
      File.write(path, "bundle")
      assert_equal path, DependencyFactory::Transport.queued_bundle({"branch" => "test"}, directory: directory, repo: "owner/repo")
    end
  end

  def test_both_paths_are_ambiguous_even_without_an_explicit_repo
    Dir.mktmpdir do |root|
      %w[aw-owner-repo-test.bundle aw-test.bundle].each { |name| File.write(File.join(root, name), "bundle") }
      assert_raises(RuntimeError) { DependencyFactory::Transport.queued_bundle({"branch" => "test"}, directory: File.join(root, "agent"), repo: "owner/repo") }
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
