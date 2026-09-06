require "test_helper"
require "json"
require "open3"
require "tmpdir"

# standard:disable Dotfiles/BanFileSystemClasses
class DependencyFactoryContextTest < Minitest::Test
  def test_default_context_uses_main_without_a_pr
    assert_equal "main", run_context.fetch("base_branch")
  end

  def test_schedule_resumes_the_single_active_batch
    assert_equal 2, run_context(pr: pr).fetch("number")
  end

  def test_stale_or_unowned_batches_fail_closed
    assert_includes run_context(pr: pr, head: "old", success: false), "Stale CI event"
    assert_includes run_context(pr: pr.merge("labels" => []), number: "2", success: false), "Not an owned dependency batch"
    assert_includes run_context(pr: pr.merge("base" => {"ref" => "other"}), number: "2", success: false), "Not an owned dependency batch"
  end

  def test_benchmark_rejects_a_moved_base
    assert_includes run_context(benchmark: true, success: false), "Benchmark base moved"
  end

  private

  def pr
    {"number" => 2, "state" => "open", "labels" => [{"name" => "dependency-update"}], "base" => {"ref" => "main"}, "head" => {"sha" => "HEAD", "repo" => {"full_name" => "test/test"}}}
  end

  def run_context(pr: nil, number: "", head: "", benchmark: false, success: true)
    Dir.mktmpdir do |root|
      File.write("#{root}/gh", "#!/bin/sh\ncase \"$2\" in */pulls\\?*) echo '#{JSON.generate(pr ? [pr] : [])}';; *) echo '#{JSON.generate(pr)}';; esac\n")
      File.write("#{root}/git", "#!/bin/sh\necho HEAD\n")
      %w[gh git].each { |name| File.chmod(0o755, "#{root}/#{name}") }
      script = File.read(File.expand_path("../../tools/ci/dependency_context.rb", __dir__)).sub('directory = "/tmp/gh-aw/agent"', "directory = #{root.inspect}")
      env = {"PATH" => "#{root}:#{ENV["PATH"]}", "GITHUB_REPOSITORY" => "test/test", "GITHUB_OUTPUT" => "#{root}/outputs", "PR_NUMBER" => number, "ISSUE_NUMBER" => "", "EVENT_HEAD" => head, "BENCHMARK" => benchmark.to_s}
      output, status = Open3.capture2e(env, "ruby", "-e", script)
      assert_equal success, status.success?, output
      success ? JSON.parse(File.read("#{root}/pr-context.json")) : output
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
