require "test_helper"

class VSCodeConfigurationStepTest < Minitest::Test
  def setup
    super
    @fake_system.stub_macos
    @step = create_step(Dotfiles::Step::VSCodeConfigurationStep)
    @extensions_file = "#{@home}/Library/Application Support/Code/User/extensions.txt"
  end

  def test_complete_checks_extensions_in_ci_mode
    stub_missing_extension

    with_ci { refute @step.complete? }
  end

  def test_should_run_in_ci_mode_when_extensions_are_missing
    stub_missing_extension

    with_ci { assert @step.should_run? }
  end

  def test_run_installs_extensions_from_file
    assert_run_executes(
      "ms-python.python\nms-vscode.cpptools\n",
      "ms-python.python",
      "code --install-extension ms-vscode.cpptools"
    )
  end

  def test_complete_fails_when_superseded_extensions_are_installed
    @fake_system.stub_file_content(@extensions_file, "nateberkopec.wordcount\n")
    @fake_system.stub_command("command -v code >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command("code --list-extensions", "ms-vscode.wordcount\nnateberkopec.wordcount\n")

    refute @step.complete?
  end

  def test_run_uninstalls_superseded_extensions
    assert_run_executes(
      "nateberkopec.wordcount\n",
      "ms-vscode.wordcount\nnateberkopec.wordcount\n",
      "code --uninstall-extension ms-vscode.wordcount"
    )
  end

  private

  def assert_run_executes(extensions_file_content, installed_extensions, expected_command)
    @fake_system.stub_file_content(@extensions_file, extensions_file_content)
    @fake_system.stub_command("code --list-extensions", installed_extensions)

    @step.run

    assert @fake_system.received_operation?(:execute, expected_command, quiet: true)
  end

  def stub_missing_extension
    @fake_system.stub_file_content(@extensions_file, "ms-python.python\n")
    @fake_system.stub_command("command -v code >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command("code --list-extensions", "")
  end
end
