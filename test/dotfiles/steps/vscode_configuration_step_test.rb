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

  def test_run_installs_extensions_from_url
    url = "https://github.com/nateberkopec/vscode-wordcount/releases/download/v0.1.0-nate.1/wordcount.vsix"
    @fake_system.stub_file_content(@extensions_file, "nateberkopec.wordcount #{url}\n")
    @fake_system.stub_command("code --list-extensions", "")

    @step.run

    assert_url_downloaded(url)
    assert_vsix_installed("wordcount.vsix")
  end

  private

  def assert_url_downloaded(url)
    downloaded = @fake_system.operations.any? { |op, command, _| op == :execute && command[0..2] == ["curl", "-fsSL", url] }
    assert downloaded
  end

  def assert_vsix_installed(filename)
    installed = @fake_system.operations.any? do |op, command, _|
      op == :execute && command[0..1] == ["code", "--install-extension"] && command[2].end_with?(filename)
    end
    assert installed
  end

  def stub_missing_extension
    @fake_system.stub_file_content(@extensions_file, "ms-python.python\n")
    @fake_system.stub_command("command -v code >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command("code --list-extensions", "")
  end
end
