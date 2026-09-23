require "test_helper"
require "open3"
require "tmpdir"

# Real history fixtures verify that a new bot SHA cannot reset the loop guard.
# standard:disable Dotfiles/BanFileSystemClasses
class DependencyFactoryRepairLoopTest < Minitest::Test
  def test_allows_the_first_native_lock_rewrite
    with_history do |root, base|
      commit(root, "Regenerate mise.lock with native provenance verification", bot: true)

      _output, status = guard(root, base, "workflow_run")

      assert status.success?
    end
  end

  def test_bails_out_after_a_second_native_lock_rewrite
    with_history do |root, base|
      commit(root, "Regenerate mise.lock with native provenance verification", bot: true)
      commit(root, "Repair dependency update lock host")
      commit(root, "Regenerate mise.lock with native provenance verification", bot: true)

      output, status = guard(root, base, "workflow_run")

      refute status.success?
      assert_includes output, "Bailing out after 2 native lock rewrites"
      assert_includes output, "See #702"
    end
  end

  def test_non_repair_events_do_not_bail_out
    with_history do |root, base|
      2.times { commit(root, "Regenerate mise.lock with native provenance verification", bot: true) }

      _output, status = guard(root, base, "workflow_dispatch")

      assert status.success?
    end
  end

  private

  def with_history
    Dir.mktmpdir do |root|
      git(root, "init", "--quiet")
      commit(root, "Base")
      yield root, git(root, "rev-parse", "HEAD").first.strip
    end
  end

  def commit(root, message, bot: false)
    File.write(File.join(root, "state"), "#{message}\n", mode: "a")
    git(root, "add", "state")
    identity = bot ? ["github-actions[bot]", "41898282+github-actions[bot]@users.noreply.github.com"] : ["Test", "test@example.test"]
    env = {
      "GIT_AUTHOR_NAME" => identity[0], "GIT_AUTHOR_EMAIL" => identity[1],
      "GIT_COMMITTER_NAME" => identity[0], "GIT_COMMITTER_EMAIL" => identity[1]
    }
    Open3.capture2e(env, "git", "-C", root, "-c", "core.hooksPath=/dev/null", "commit", "--no-gpg-sign", "-qm", message)
  end

  def guard(root, base, event)
    script = File.expand_path("../../tools/ci/check_dependency_repair_loop.sh", __dir__)
    Open3.capture2e("bash", script, base, event, chdir: root)
  end

  def git(root, *args)
    Open3.capture2e("git", "-C", root, "-c", "core.hooksPath=/dev/null", *args)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
