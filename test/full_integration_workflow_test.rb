require "test_helper"
require "yaml"

class FullIntegrationWorkflowTest < Minitest::Test
  def test_macos_jobs_install_tinycast
    %w[integration-test non-admin-integration-test].each do |job_name|
      tools = integration_tools_for(job_name)

      assert_includes tools, "github:abue-ammar/tinycast", "#{job_name} must install Tinycast before dotf runs"
    end
  end

  private

  def integration_tools_for(job_name)
    workflow = YAML.safe_load_file(File.expand_path("../.github/workflows/full-integration-test.yml", __dir__))
    step = workflow.fetch("jobs").fetch(job_name).fetch("steps").find do |candidate|
      candidate["name"]&.start_with?("Run dotfiles integration script")
    end
    step.fetch("env").fetch("MISE_CI_TOOLS").split(",")
  end
end
