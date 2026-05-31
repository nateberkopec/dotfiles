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
    stub_installed_extensions("ms-python.python")

    @step.run

    assert @fake_system.received_operation?(:execute, "code --install-extension ms-vscode.cpptools", quiet: true)
  end

  def test_run_installs_configured_extensions_from_github_release_assets
    stub_extension_source
    @fake_system.stub_file_content(@extensions_file, "nateberkopec.simple-yaml-tools\n")
    stub_installed_extensions
    @fake_system.stub_command("command -v gh >/dev/null 2>&1", "", exit_status: 0)

    @step.run

    assert @fake_system.received_operation?(:mkdir_p, "/tmp/dotfiles-vscode-extensions")
    assert @fake_system.received_operation?(:execute, "gh release download v0.0.1 -R nateberkopec/simple-yaml-tools -p simple-yaml-tools-0.0.1.vsix -D /tmp/dotfiles-vscode-extensions --clobber", quiet: true)
    assert @fake_system.received_operation?(:execute, "code --install-extension /tmp/dotfiles-vscode-extensions/simple-yaml-tools-0.0.1.vsix", quiet: true)
  end

  def test_run_skips_github_release_assets_when_extension_is_already_installed
    stub_extension_source
    @fake_system.stub_file_content(@extensions_file, "nateberkopec.simple-yaml-tools\n")
    stub_installed_extensions("nateberkopec.simple-yaml-tools")

    @step.run

    refute @fake_system.received_operation?(:execute, "gh release download v0.0.1 -R nateberkopec/simple-yaml-tools -p simple-yaml-tools-0.0.1.vsix -D /tmp/dotfiles-vscode-extensions --clobber", quiet: true)
    refute @fake_system.received_operation?(:execute, "code --install-extension /tmp/dotfiles-vscode-extensions/simple-yaml-tools-0.0.1.vsix", quiet: true)
  end

  def test_run_reports_missing_gh_for_github_release_assets
    stub_extension_source
    @fake_system.stub_file_content(@extensions_file, "nateberkopec.simple-yaml-tools\n")
    stub_installed_extensions
    @fake_system.stub_command("command -v gh >/dev/null 2>&1", "", exit_status: 1)

    @step.run

    assert_includes @step.errors, "gh CLI is required to install nateberkopec.simple-yaml-tools from GitHub release assets"
    refute @fake_system.received_operation?(:execute, "gh release download v0.0.1 -R nateberkopec/simple-yaml-tools -p simple-yaml-tools-0.0.1.vsix -D /tmp/dotfiles-vscode-extensions --clobber", quiet: true)
  end

  def test_run_reports_github_download_failures
    stub_extension_source
    @fake_system.stub_file_content(@extensions_file, "nateberkopec.simple-yaml-tools\n")
    stub_installed_extensions
    @fake_system.stub_command("command -v gh >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command("gh release download v0.0.1 -R nateberkopec/simple-yaml-tools -p simple-yaml-tools-0.0.1.vsix -D /tmp/dotfiles-vscode-extensions --clobber", "not found", exit_status: 1)

    @step.run

    assert_includes @step.errors, "gh release download v0.0.1 -R nateberkopec/simple-yaml-tools -p simple-yaml-tools-0.0.1.vsix -D /tmp/dotfiles-vscode-extensions --clobber failed (status 1): not found"
    refute @fake_system.received_operation?(:execute, "code --install-extension /tmp/dotfiles-vscode-extensions/simple-yaml-tools-0.0.1.vsix", quiet: true)
  end

  def test_complete_checks_extension_directories_without_running_code_cli
    @fake_system.stub_file_content(@extensions_file, "ms-python.python\n")
    @fake_system.stub_command("command -v code >/dev/null 2>&1", "", exit_status: 0)
    stub_installed_extensions("ms-python.python")

    assert @step.complete?

    refute @fake_system.received_operation?(:execute, "code --list-extensions", quiet: true)
  end

  private

  def stub_extension_source
    @fake_system.stub_file_content(
      File.join(@dotfiles_dir, "config", "config.yml"),
      YAML.dump(
        "vscode_extension_sources" => {
          "nateberkopec.simple-yaml-tools" => {
            "github" => "nateberkopec/simple-yaml-tools",
            "tag" => "v0.0.1",
            "asset" => "simple-yaml-tools-0.0.1.vsix"
          }
        }
      )
    )
  end

  def stub_missing_extension
    @fake_system.stub_file_content(@extensions_file, "ms-python.python\n")
    @fake_system.stub_command("command -v code >/dev/null 2>&1", "", exit_status: 0)
    stub_installed_extensions
  end

  def stub_installed_extensions(*extension_ids)
    extension_ids.each do |extension_id|
      @fake_system.filesystem["#{@home}/.vscode/extensions/#{extension_id}-1.0.0"] = :directory
    end
  end
end
