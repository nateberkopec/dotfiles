require "test_helper"

class ConfigureTrackpadStepTest < Minitest::Test
  def setup
    super
    stub_trackpad_config
  end

  def stub_trackpad_config
    config_content = <<~YAML
      trackpad_settings:
        com.apple.AppleMultitouchTrackpad:
          Clicking: 0
          TrackpadRightClick: 1
          FirstClickThreshold: 1
        NSGlobalDomain:
          com.apple.mouse.scaling: 2
    YAML

    @fake_system.stub_file_content("#{@dotfiles_dir}/config/trackpad.yml", config_content)
  end

  def test_step_exists
    step = create_step(Dotfiles::Step::ConfigureTrackpadStep)
    assert_instance_of Dotfiles::Step::ConfigureTrackpadStep, step
  end

  def test_runs_defaults_write_commands_for_all_settings
    step = create_step(Dotfiles::Step::ConfigureTrackpadStep)
    step.run

    assert @fake_system.received_operation?(:execute, "defaults write com.apple.AppleMultitouchTrackpad Clicking -int 0", {quiet: true})
    assert @fake_system.received_operation?(:execute, "defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -int 1", {quiet: true})
    assert @fake_system.received_operation?(:execute, "defaults write com.apple.AppleMultitouchTrackpad FirstClickThreshold -int 1", {quiet: true})
    assert @fake_system.received_operation?(:execute, "defaults write -g com.apple.mouse.scaling -int 2", {quiet: true})
  end

  def test_complete_when_all_settings_match
    step = create_step(Dotfiles::Step::ConfigureTrackpadStep)

    @fake_system.stub_command("defaults read com.apple.AppleMultitouchTrackpad Clicking", "0", exit_status: 0)
    @fake_system.stub_command("defaults read com.apple.AppleMultitouchTrackpad TrackpadRightClick", "1", exit_status: 0)
    @fake_system.stub_command("defaults read com.apple.AppleMultitouchTrackpad FirstClickThreshold", "1", exit_status: 0)
    @fake_system.stub_command("defaults read -g com.apple.mouse.scaling", "2", exit_status: 0)

    assert step.complete?
  end

  def test_incomplete_when_any_setting_differs
    step = create_step(Dotfiles::Step::ConfigureTrackpadStep)

    @fake_system.stub_command("defaults read com.apple.AppleMultitouchTrackpad Clicking", "1", exit_status: 0)
    @fake_system.stub_command("defaults read com.apple.AppleMultitouchTrackpad TrackpadRightClick", "1", exit_status: 0)
    @fake_system.stub_command("defaults read com.apple.AppleMultitouchTrackpad FirstClickThreshold", "1", exit_status: 0)
    @fake_system.stub_command("defaults read -g com.apple.mouse.scaling", "2", exit_status: 0)

    refute step.complete?
  end

  def test_incomplete_when_setting_command_fails
    step = create_step(Dotfiles::Step::ConfigureTrackpadStep)

    @fake_system.stub_command("defaults read com.apple.AppleMultitouchTrackpad Clicking", "", exit_status: 1)
    @fake_system.stub_command("defaults read com.apple.AppleMultitouchTrackpad TrackpadRightClick", "1", exit_status: 0)
    @fake_system.stub_command("defaults read com.apple.AppleMultitouchTrackpad FirstClickThreshold", "1", exit_status: 0)
    @fake_system.stub_command("defaults read -g com.apple.mouse.scaling", "2", exit_status: 0)

    refute step.complete?
  end

  def test_update_reads_current_settings_and_writes_to_config
    step = create_step(Dotfiles::Step::ConfigureTrackpadStep)

    @fake_system.stub_command("defaults read com.apple.AppleMultitouchTrackpad Clicking", "1", exit_status: 0)
    @fake_system.stub_command("defaults read com.apple.AppleMultitouchTrackpad TrackpadRightClick", "1", exit_status: 0)
    @fake_system.stub_command("defaults read com.apple.AppleMultitouchTrackpad FirstClickThreshold", "2", exit_status: 0)
    @fake_system.stub_command("defaults read -g com.apple.mouse.scaling", "3", exit_status: 0)

    step.update
    write_op = @fake_system.operations.find { |op| op[0] == :write_file && op[1] == "#{@dotfiles_dir}/config/trackpad.yml" }
    assert write_op, "Expected write_file operation to #{@dotfiles_dir}/config/trackpad.yml"
    written_content = write_op[2]
    parsed = YAML.safe_load(written_content)

    assert_equal 1, parsed["trackpad_settings"]["com.apple.AppleMultitouchTrackpad"]["Clicking"]
    assert_equal 1, parsed["trackpad_settings"]["com.apple.AppleMultitouchTrackpad"]["TrackpadRightClick"]
    assert_equal 2, parsed["trackpad_settings"]["com.apple.AppleMultitouchTrackpad"]["FirstClickThreshold"]
    assert_equal 3, parsed["trackpad_settings"]["NSGlobalDomain"]["com.apple.mouse.scaling"]
  end

  def test_update_only_updates_existing_keys
    step = create_step(Dotfiles::Step::ConfigureTrackpadStep)

    @fake_system.stub_command("defaults read com.apple.AppleMultitouchTrackpad Clicking", "0", exit_status: 0)
    @fake_system.stub_command("defaults read com.apple.AppleMultitouchTrackpad TrackpadRightClick", "1", exit_status: 0)
    @fake_system.stub_command("defaults read com.apple.AppleMultitouchTrackpad FirstClickThreshold", "1", exit_status: 0)
    @fake_system.stub_command("defaults read -g com.apple.mouse.scaling", "2", exit_status: 0)

    step.update
    read_operations = @fake_system.operations.select { |op| op[0] == :execute && op[1].start_with?("defaults read") }
    assert_equal 4, read_operations.size
  end
end
