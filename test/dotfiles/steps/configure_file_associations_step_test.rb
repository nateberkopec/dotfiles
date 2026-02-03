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
    stub_bundle_installed("com.microsoft.VSCode", "/Applications/Visual Studio Code.app")
  end

  def test_runs_duti_command_for_each_extension
    step.run
    assert_executed("duti -s com.microsoft.VSCode .md all")
  end

  def test_complete_when_handler_matches
    @fake_system.stub_command(
      "duti -x .md 2>/dev/null",
      "Visual Studio Code\n/Applications/Visual Studio Code.app\ncom.microsoft.VSCode",
      0
    )
    assert_complete
  end

  def test_incomplete_when_handler_differs
    @fake_system.stub_command(
      "duti -x .md 2>/dev/null",
      "TextEdit\n/System/Applications/TextEdit.app\ncom.apple.TextEdit",
      0
    )
    assert_incomplete
  end

  def test_incomplete_when_duti_fails
    @fake_system.stub_command("duti -x .md 2>/dev/null", "", exit_status: 1)
    assert_incomplete
  end

  def test_skips_when_bundle_missing
    stub_bundle_missing("com.microsoft.VSCode")

    step.run

    refute_executed("duti -s com.microsoft.VSCode .md all")
    assert_complete
  end

  def test_handles_multiple_extensions
    write_config(:file_associations, {
      "file_associations" => {
        "com.microsoft.VSCode" => [".md", ".txt"],
        "com.apple.Safari" => [".html"]
      }
    })
    rebuild_step!
    stub_bundle_installed("com.microsoft.VSCode", "/Applications/Visual Studio Code.app")
    stub_bundle_installed("com.apple.Safari", "/Applications/Safari.app")

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

  private

  def stub_bundle_installed(bundle_id, path)
    @fake_system.stub_command("mdfind \"kMDItemCFBundleIdentifier == '#{bundle_id}'\"", path, 0)
  end

  def stub_bundle_missing(bundle_id)
    @fake_system.stub_command("mdfind \"kMDItemCFBundleIdentifier == '#{bundle_id}'\"", "", 0)
  end
end
