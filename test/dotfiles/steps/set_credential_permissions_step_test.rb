require "test_helper"

class SetCredentialPermissionsStepTest < StepTestCase
  step_class Dotfiles::Step::SetCredentialPermissionsStep

  def setup
    super
    @fake_system.stub_macos
  end

  def test_run_restricts_existing_credential_files
    credential_files.each { |file| @fake_system.stub_file_content(file, "credential") }

    step.run

    credential_files.each { |file| assert_command_run(:chmod, 0o600, file) }
  end

  def test_run_skips_missing_credential_files
    assert_nil step.run
    credential_files.each { |file| refute_command_run(:chmod, 0o600, file) }
  end

  def test_complete_when_credential_files_are_restricted
    credential_files.each do |file|
      @fake_system.stub_file_content(file, "credential")
      @fake_system.stub_command(["stat", "-f", "%Lp", file], "600")
    end

    assert_complete
  end

  def test_incomplete_when_a_credential_file_is_too_open
    file = credential_files.first
    @fake_system.stub_file_content(file, "credential")
    @fake_system.stub_command(["stat", "-f", "%Lp", file], "644")

    assert_incomplete
  end

  def test_complete_when_credential_files_do_not_exist
    assert_complete
  end

  private

  def credential_files
    [File.join(@home, ".gem", "credentials"), File.join(@home, ".aws", "credentials")]
  end
end
