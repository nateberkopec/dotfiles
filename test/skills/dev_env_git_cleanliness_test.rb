# standard:disable Dotfiles/BanFileSystemClasses -- black-box script tests require real temporary files
require_relative "../test_helper"
require "open3"
require "tmpdir"

class DevEnvGitCleanlinessTest < Minitest::Test
  CHECK = File.expand_path("../../files/home/.claude/skills/dev-env-setup/scripts/check-dev-env/git.fish", __dir__)

  def setup
    skip "fish is required for checker tests" unless system("fish", "--version", out: File::NULL, err: File::NULL)
  end

  def test_arbitrary_untracked_file_fails
    Dir.mktmpdir do |dir|
      init_repo(dir)
      File.write(File.join(dir, "unexpected.local"), "x")

      output = run_check(dir)

      assert_includes output, "FAIL:git clean (1 changed paths; names redacted)"
      refute_includes output, "unexpected.local"
    end
  end

  def test_git_status_failure_does_not_report_clean
    Dir.mktmpdir do |dir|
      git = File.join(dir, "git")
      File.write(git, <<~FISH)
        #!/usr/bin/env fish
        if contains -- rev-parse $argv
          echo true
          exit 0
        end
        exit 2
      FISH
      File.chmod(0o755, git)

      output = run_check(dir, path: dir)

      assert_includes output, "FAIL:git clean (status unavailable)"
      refute_includes output, "PASS:git clean"
    end
  end

  def test_git_file_repository_is_detected_and_clean_passes
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".git"), "gitdir: elsewhere\n")
      git = File.join(dir, "git")
      File.write(git, <<~FISH)
        #!/usr/bin/env fish
        test "$argv[-1]" = --is-inside-work-tree; and echo true
        exit 0
      FISH
      File.chmod(0o755, git)

      assert_includes run_check(dir, path: dir), "PASS:git clean"
    end
  end

  private

  def init_repo(dir)
    system("git", "-C", dir, "init", "-q") or flunk
    File.write(File.join(dir, "tracked"), "x")
    system({"GIT_AUTHOR_NAME" => "Test", "GIT_AUTHOR_EMAIL" => "test@example.com",
      "GIT_COMMITTER_NAME" => "Test", "GIT_COMMITTER_EMAIL" => "test@example.com"},
      "git", "-C", dir, "add", ".") or flunk
    system({"GIT_AUTHOR_NAME" => "Test", "GIT_AUTHOR_EMAIL" => "test@example.com",
      "GIT_COMMITTER_NAME" => "Test", "GIT_COMMITTER_EMAIL" => "test@example.com"},
      "git", "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null", "-C", dir,
      "commit", "-qm", "initial") or flunk
  end

  def run_check(dir, path: nil)
    prefix = path ? "set -gx PATH '#{path}' $PATH; " : ""
    script = "#{prefix}function check_pass; echo PASS:$argv; end; function check_fail; echo FAIL:$argv[1]; end; set target_dir '#{dir}'; source '#{CHECK}'; check_git_cleanliness"
    Open3.capture2("fish", "-c", script).first
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
