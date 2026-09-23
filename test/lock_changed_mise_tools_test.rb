require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

# Exercises the shell boundary used directly by both native workflow jobs.
# standard:disable Dotfiles/BanFileSystemClasses
class LockChangedMiseToolsTest < Minitest::Test
  SCRIPT = File.expand_path("../tools/ci/lock_changed_mise_tools.sh", __dir__)
  WORKFLOW = File.expand_path("../.github/workflows/lock-provenance.yml", __dir__)

  def test_selector_failure_fails_the_workflow_shell_boundary
    Dir.mktmpdir do |root|
      bin = File.join(root, "bin")
      FileUtils.mkdir_p(bin)
      File.write(File.join(bin, "bundle"), <<~SH)
        #!/usr/bin/env bash
        echo "selector rejected lock drift" >&2
        exit 23
      SH
      FileUtils.chmod("+x", File.join(bin, "bundle"))

      output, status = Open3.capture2e({"PATH" => "#{bin}:#{ENV.fetch("PATH")}"}, "bash", SCRIPT, "a" * 40, native_platform)

      assert_equal 23, status.exitstatus
      assert_includes output, "selector rejected lock drift"
      assert_includes output, "Failed to select changed mise tools"
    end
  end

  def test_both_native_jobs_checkout_full_history_for_selection
    jobs = YAML.safe_load_file(WORKFLOW).fetch("jobs")

    %w[lock-linux lock-macos].each do |job|
      checkout = jobs.fetch(job).fetch("steps").find { |step| step["name"] == "Checkout repository" }

      assert_equal 0, checkout.fetch("with").fetch("fetch-depth"), "#{job} must fetch the comparison base"
    end
  end

  private

  def native_platform
    os = RbConfig::CONFIG.fetch("host_os").match?(/darwin/) ? "macos" : "linux"
    arch = RbConfig::CONFIG.fetch("host_cpu").match?(/arm|aarch/) ? "arm64" : "x64"
    "#{os}-#{arch}"
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
