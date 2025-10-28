require "test_helper"

class VSCodeConfigurationStepTest < Minitest::Test
  def setup
    super
    @step = create_step(Dotfiles::Step::VSCodeConfigurationStep)
    @step.config.paths = {
      "application_paths" => {
        "vscode_user_dir" => "#{@home}/Library/Application Support/Code/User",
        "vscode_settings" => "#{@home}/Library/Application Support/Code/User/settings.json",
        "vscode_keybindings" => "#{@home}/Library/Application Support/Code/User/keybindings.json"
      },
      "dotfiles_sources" => {
        "vscode_settings" => "files/vscode/settings.json",
        "vscode_keybindings" => "files/vscode/keybindings.json",
        "vscode_extensions" => "files/vscode/extensions.txt"
      }
    }
  end

  def test_complete_when_files_exist
    @fake_system.stub_file_content("#{@home}/Library/Application Support/Code/User/settings.json", "{}")
    @fake_system.stub_file_content("#{@home}/Library/Application Support/Code/User/keybindings.json", "[]")

    assert @step.complete?
  end

  def test_not_complete_when_files_missing
    refute @step.complete?
  end

  def test_run_copies_config_files
    src_settings = File.join(@dotfiles_dir, "files/vscode/settings.json")
    src_keybindings = File.join(@dotfiles_dir, "files/vscode/keybindings.json")
    dest_dir = "#{@home}/Library/Application Support/Code/User"

    @fake_system.stub_file_content(src_settings, "{}")
    @fake_system.stub_file_content(src_keybindings, "[]")

    ENV["CI"] = "true"
    @step.run
    ENV.delete("CI")

    assert @fake_system.received_operation?(:mkdir_p, dest_dir)
    assert @fake_system.received_operation?(:cp, src_settings, dest_dir)
    assert @fake_system.received_operation?(:cp, src_keybindings, dest_dir)
  end
end
