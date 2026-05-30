require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

# standard:disable Dotfiles/BanFileSystemClasses
class CheckHumanOnlyFilesTest < Minitest::Test
  def test_allows_default_empty_index
    with_git_repo do |repo|
      assert_check_succeeds(repo)
    end
  end

  def test_blocks_staged_readme_changes
    with_git_repo do |repo|
      write_staged_file(repo, "README.md", "human words\n")

      _stdout, stderr, status = run_check(repo)

      refute status.success?
      assert_includes stderr, "Human-only files are staged"
      assert_includes stderr, "README.md"
    end
  end

  def test_blocks_staged_docs_changes
    with_git_repo do |repo|
      write_staged_file(repo, "docs/guide.md", "human words\n")

      _stdout, stderr, status = run_check(repo)

      refute status.success?
      assert_includes stderr, "docs/guide.md"
    end
  end

  def test_allows_bypass_for_human_only_changes
    with_git_repo do |repo|
      write_staged_file(repo, "README.md", "human words\n")

      assert_check_succeeds(repo, "DOTF_ALLOW_HUMAN_ONLY_CHANGES" => "1")
    end
  end

  def test_allows_staged_non_human_only_changes
    with_git_repo do |repo|
      write_staged_file(repo, "lib/example.rb", "puts 'ok'\n")

      assert_check_succeeds(repo)
    end
  end

  private

  def assert_check_succeeds(repo, env = {})
    _stdout, stderr, status = run_check(repo, env)

    assert status.success?, stderr
  end

  def run_check(repo, env = {})
    script = File.expand_path("../tools/check_human_only_files.rb", __dir__)
    Open3.capture3(env, "ruby", script, chdir: repo)
  end

  def with_git_repo
    Dir.mktmpdir do |repo|
      system("git", "init", repo, out: File::NULL, err: File::NULL)
      yield repo
    end
  end

  def write_staged_file(repo, relative_path, content)
    path = File.join(repo, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    system("git", "-C", repo, "add", relative_path, out: File::NULL, err: File::NULL)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
