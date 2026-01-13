require "test_helper"

class ConfigureFileAssociationsStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureFileAssociationsStep

  def setup
    super
    write_config(:file_associations, {
      "file_associations" => {
        "com.microsoft.VSCode" => [".md"]
      }
    })
  end

  def test_runs_duti_command_for_each_extension
    step.run
    assert_executed("duti -s com.microsoft.VSCode .md all")
  end

  def test_complete_when_handler_matches
    @fake_system.stub_command(
      "duti -x .md 2>/dev/null",
      ".md:\n\tVisual Studio Code.app\n\t/Applications/Visual Studio Code.app\n\tBundle ID:  com.microsoft.VSCode",
      0
    )
    assert_complete
  end

  def test_incomplete_when_handler_differs
    @fake_system.stub_command(
      "duti -x .md 2>/dev/null",
      ".md:\n\tTextEdit.app\n\t/System/Applications/TextEdit.app\n\tBundle ID:  com.apple.TextEdit",
      0
    )
    assert_incomplete
  end

  def test_incomplete_when_duti_fails
    @fake_system.stub_command("duti -x .md 2>/dev/null", "", exit_status: 1)
    assert_incomplete
  end

  def test_handles_multiple_extensions
    write_config(:file_associations, {
      "file_associations" => {
        "com.microsoft.VSCode" => [".md", ".txt"],
        "com.apple.Safari" => [".html"]
      }
    })
    rebuild_step!

    step.run

    assert_executed("duti -s com.microsoft.VSCode .md all")
    assert_executed("duti -s com.microsoft.VSCode .txt all")
    assert_executed("duti -s com.apple.Safari .html all")
  end

  def test_complete_with_no_file_associations_configured
    write_config(:file_associations, {"file_associations" => {}})
    rebuild_step!
    assert_complete
  end
end
