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
    @fake_system.stub_file_content(@extensions_file, "ms-python.python\nms-vscode.cpptools\n")
    @fake_system.stub_command("code --list-extensions", "ms-python.python")

    @step.run

    assert @fake_system.received_operation?(:execute, "code --install-extension ms-vscode.cpptools", quiet: true)
  end

  private

  def stub_missing_extension
    @fake_system.stub_file_content(@extensions_file, "ms-python.python\n")
    @fake_system.stub_command("command -v code >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command("code --list-extensions", "")
  end
end
