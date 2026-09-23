require "test_helper"
require "yaml"

class FullIntegrationWorkflowTest < Minitest::Test
  def test_macos_jobs_install_tinycast
    tools_by_job = {
      "integration-test" => matrix_tools_for("macos-latest"),
      "non-admin-integration-test" => integration_tools_for("non-admin-integration-test")
    }

    tools_by_job.each do |job_name, tools|
      assert_includes tools, "github:abue-ammar/tinycast", "#{job_name} must install Tinycast before dotf runs"
    end
  end

  def test_linux_job_does_not_probe_macos_only_tinycast
    refute_includes matrix_tools_for("ubuntu-22.04"), "github:abue-ammar/tinycast"
  end

  private

  def integration_tools_for(job_name)
    job = workflow.fetch("jobs").fetch(job_name)
    step = job.fetch("steps").find do |candidate|
      candidate["name"]&.start_with?("Run dotfiles integration script")
    end
    step.fetch("env").fetch("MISE_CI_TOOLS").split(",")
  end

  def matrix_tools_for(os)
    matrix = workflow.dig("jobs", "integration-test", "strategy", "matrix", "include")
    matrix.find { |entry| entry.fetch("os") == os }.fetch("mise_ci_tools").split(",")
  end

  def workflow
    @workflow ||= YAML.safe_load_file(File.expand_path("../.github/workflows/full-integration-test.yml", __dir__))
  end
end
