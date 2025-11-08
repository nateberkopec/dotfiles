require "test_helper"

class VSCodeConfigurationStepTest < Minitest::Test
  def setup
    super
    @step = create_step(Dotfiles::Step::VSCodeConfigurationStep)
    @step.config.paths = vscode_paths
  end

  def vscode_paths
    user_dir = "#{@home}/Library/Application Support/Code/User"
    {
      "application_paths" => {
        "vscode_user_dir" => user_dir,
        "vscode_settings" => "#{user_dir}/settings.json",
        "vscode_keybindings" => "#{user_dir}/keybindings.json"
      },
      "dotfiles_sources" => %w[settings keybindings extensions].each_with_object({}) do |name, h|
        h["vscode_#{name}"] = "files/vscode/#{name}.#{(name == "extensions") ? "txt" : "json"}"
      end
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
