require "test_helper"
require "open3"
require "tmpdir"

# standard:disable Dotfiles/BanFileSystemClasses
class DotfUpdateNoticeTest < Minitest::Test
  FUNCTION_PATH = File.expand_path("../../files/home/.config/fish/functions/__dotf_refresh_update_notice.fish", __dir__)

  def setup
    skip "Fish is not installed" unless system("fish", "--version", out: File::NULL)
  end

  def test_marks_dotfiles_when_origin_main_advanced_since_last_run
    with_repositories do |tmpdir, source, checkout, initial_sha|
      commit_and_push(source, "new change")
      run_check(checkout, File.join(tmpdir, "state"), initial_sha)

      assert File.exist?(File.join(tmpdir, "state", "dotfiles", "needs-run"))
    end
  end

  def test_leaves_no_mark_when_last_run_includes_origin_main
    with_repositories do |tmpdir, source, checkout, _initial_sha|
      current_sha = commit_and_push(source, "new change")
      run_check(checkout, File.join(tmpdir, "state"), current_sha)

      refute File.exist?(File.join(tmpdir, "state", "dotfiles", "needs-run"))
    end
  end

  def test_preserves_existing_mark_without_a_successful_run
    with_repositories do |tmpdir, _source, checkout, _initial_sha|
      state_home = File.join(tmpdir, "state")
      state_dir = File.join(state_home, "dotfiles")
      FileUtils.mkdir_p(state_dir)
      File.write(File.join(state_dir, "needs-run"), "dotf run\n")

      run_check(checkout, state_home, nil)

      assert File.exist?(File.join(state_dir, "needs-run"))
    end
  end

  private

  def with_repositories
    Dir.mktmpdir("dotf-update-notice") do |tmpdir|
      remote = File.join(tmpdir, "remote.git")
      source = File.join(tmpdir, "source")
      checkout = File.join(tmpdir, "checkout")
      run_git(tmpdir, "init", "--bare", remote)
      run_git(tmpdir, "init", "--initial-branch=main", source)
      run_git(source, "config", "user.email", "test@example.com")
      run_git(source, "config", "user.name", "Test")
      initial_sha = commit_and_push(source, "initial", remote: remote)
      run_git(tmpdir, "clone", "--branch", "main", remote, checkout)
      yield tmpdir, source, checkout, initial_sha
    end
  end

  def commit_and_push(source, message, remote: "origin")
    File.write(File.join(source, "state"), message)
    run_git(source, "add", "state")
    run_git(source, "commit", "--no-gpg-sign", "-m", message)
    run_git(source, "remote", "add", "origin", remote) unless remote == "origin"
    run_git(source, "push", "origin", "main")
    run_git(source, "rev-parse", "HEAD").strip
  end

  def run_check(checkout, state_home, last_run_sha)
    state_dir = File.join(state_home, "dotfiles")
    FileUtils.mkdir_p(state_dir)
    File.write(File.join(state_dir, "last-run-sha"), "#{last_run_sha}\n") if last_run_sha
    command = "source #{Shellwords.escape(FUNCTION_PATH)}; __dotf_refresh_update_notice"
    output, status = Open3.capture2e(
      {"DOTFILES_DIR" => checkout, "XDG_STATE_HOME" => state_home},
      "fish", "--no-config", "--command", command
    )
    assert status.success?
    assert_empty output
  end

  def run_git(directory, *arguments)
    output, status = Open3.capture2e("git", "-C", directory, *arguments)
    assert status.success?, output
    output
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
