require "test_helper"

class VSCodeConfigurationStepTest < Minitest::Test
  def setup
    super
    @fake_system.stub_macos
    @step = create_step(Dotfiles::Step::VSCodeConfigurationStep)
    @extensions_file = "#{@home}/Library/Application Support/Code/User/extensions.txt"
  end

  def test_complete_in_ci_mode
    with_ci { assert @step.complete? }
  end

  def test_should_not_run_in_ci_mode
    with_ci { refute @step.should_run? }
  end

  def test_run_installs_extensions_from_file
    @fake_system.stub_file_content(@extensions_file, "ms-python.python\nms-vscode.cpptools\n")
    @fake_system.stub_command("code --list-extensions", "ms-python.python")

    @step.run

    assert @fake_system.received_operation?(:execute, "code --install-extension ms-vscode.cpptools", quiet: true)
  end
end
