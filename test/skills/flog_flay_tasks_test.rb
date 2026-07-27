# standard:disable Dotfiles/BanFileSystemClasses -- black-box script tests require real temporary files
require_relative "../test_helper"
require "open3"
require "tmpdir"

class FlogFlayTasksTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def test_flog_fails_class_method_at_threshold
    output, status = run_task("flog", "  25.0: Foo::build")

    refute status.success?
    assert_includes output, "reached threshold"
  end

  def test_flay_fails_when_total_is_missing
    output, status = run_task("flay", "tool exploded", tool_status: 1)

    refute status.success?
    assert_includes output, "no parseable total score"
  end

  def test_flay_accepts_parseable_below_threshold_total
    output, status = run_task("flay", "Total score (lower is better) = 9", tool_status: 1)

    assert status.success?, output
    assert_includes output, "flay passed"
  end

  private

  def run_task(task, tool_output, tool_status: 0)
    Dir.mktmpdir do |dir|
      bundle = File.join(dir, "bundle")
      File.write(bundle, <<~RUBY)
        #!/usr/bin/env ruby
        puts ENV.fetch("TOOL_OUTPUT")
        exit ENV.fetch("TOOL_STATUS").to_i
      RUBY
      File.chmod(0o755, bundle)
      code = "require 'rake'; load File.join(ENV.fetch('ROOT'), 'Rakefile'); Rake::Task[ENV.fetch('TASK')].invoke"
      env = {"PATH" => "#{dir}:#{ENV.fetch("PATH")}", "ROOT" => ROOT, "TASK" => task,
             "TOOL_OUTPUT" => tool_output, "TOOL_STATUS" => tool_status.to_s}
      return Open3.capture2e(env, "ruby", "-e", code, chdir: ROOT)
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
