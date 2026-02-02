require "test_helper"

class InstallGeminiNanobananaExtensionStepTest < StepTestCase
  step_class Dotfiles::Step::InstallGeminiNanobananaExtensionStep

  def test_should_not_run_without_gemini
    stub_gemini_missing

    refute_should_run
  end

  def test_should_run_with_gemini_and_missing_extension
    stub_gemini_present

    assert_should_run
  end

  def test_run_installs_extension_when_missing
    stub_gemini_present

    step.run

    assert_executed(install_command)
  end

  def test_run_skips_when_extension_installed
    stub_gemini_present
    stub_extension_installed

    step.run

    refute_executed(install_command)
  end

  def test_complete_returns_true_when_gemini_missing
    stub_gemini_missing

    assert_complete
  end

  def test_complete_returns_true_when_extension_installed
    stub_gemini_present
    stub_extension_installed

    assert_complete
  end

  def test_complete_returns_false_when_extension_missing
    stub_gemini_present

    refute step.complete?
    assert_includes step.errors, "Nano Banana extension not installed at #{extension_path}"
  end

  private

  def install_command
    "gemini extensions install https://github.com/gemini-cli-extensions/nanobanana --consent"
  end

  def extension_path
    File.join(@home, ".gemini", "extensions", "nanobanana")
  end

  def stub_extension_installed
    @fake_system.filesystem[extension_path] = :directory
  end

  def stub_gemini_missing
    @fake_system.stub_command("command -v gemini >/dev/null 2>&1", "", exit_status: 1)
  end

  def stub_gemini_present
    @fake_system.stub_command("command -v gemini >/dev/null 2>&1", "", exit_status: 0)
  end
end
