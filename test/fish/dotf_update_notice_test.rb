require "test_helper"
require "open3"
require "tmpdir"

# standard:disable Dotfiles/BanFileSystemClasses
class DotfUpdateNoticeTest < Minitest::Test
  GIT_ENV = ENV.keys.grep(/\AGIT_/).to_h { |name| [name, nil] }.freeze
  CONFIG_PATH = File.expand_path("../../files/home/.config/fish/config.fish", __dir__)
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

  def test_greeting_checks_for_changes_in_the_background
    with_repositories do |tmpdir, source, checkout, initial_sha|
      commit_and_push(source, "new change")
      state_home = File.join(tmpdir, "state")
      state_dir = File.join(state_home, "dotfiles")
      home = File.join(tmpdir, "home")
      function_dir = File.join(home, ".config", "fish", "functions")
      FileUtils.mkdir_p(state_dir)
      FileUtils.mkdir_p(function_dir)
      File.write(File.join(state_dir, "last-run-sha"), "#{initial_sha}\n")
      FileUtils.cp(FUNCTION_PATH, function_dir)

      output, status = Open3.capture2e(
        GIT_ENV.merge("DOTFILES_DIR" => checkout, "HOME" => home, "XDG_STATE_HOME" => state_home),
        "fish", "--no-config", "--command", "source #{Shellwords.escape(CONFIG_PATH)}; fish_greeting"
      )

      assert status.success?, output
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
      sleep 0.01 until File.exist?(File.join(state_dir, "needs-run")) || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      assert File.exist?(File.join(state_dir, "needs-run"))
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
      GIT_ENV.merge("DOTFILES_DIR" => checkout, "XDG_STATE_HOME" => state_home),
      "fish", "--no-config", "--command", command
    )
    assert status.success?
    assert_empty output
  end

  def run_git(directory, *arguments)
    output, status = Open3.capture2e(GIT_ENV, "git", "-c", "core.hooksPath=/dev/null", "-C", directory, *arguments)
    assert status.success?, output
    output
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
