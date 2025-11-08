require "test_helper"

class DisableAnimationsStepTest < Minitest::Test
  def setup
    super
    stub_animations_config
  end

  def stub_animations_config
    config_content = <<~YAML
      animation_settings:
        NSGlobalDomain:
          NSAutomaticWindowAnimationsEnabled: 0
          NSWindowResizeTime: 0.001
        com.apple.dock:
          launchanim: 0
          autohide-time-modifier: 0.4
        com.apple.finder:
          DisableAllAnimations: 1
    YAML

    @fake_system.stub_file_content("#{@dotfiles_dir}/config/animations.yml", config_content)
  end

  def stub_default_outputs
    @fake_system.stub_command("defaults read -g NSAutomaticWindowAnimationsEnabled", "0", exit_status: 0)
    @fake_system.stub_command("defaults read -g NSWindowResizeTime", "0.001", exit_status: 0)
    @fake_system.stub_command("defaults read com.apple.dock launchanim", "0", exit_status: 0)
    @fake_system.stub_command("defaults read com.apple.dock autohide-time-modifier", "0.4", exit_status: 0)
    @fake_system.stub_command("defaults read com.apple.finder DisableAllAnimations", "1", exit_status: 0)
  end

  def test_step_exists
    step = create_step(Dotfiles::Step::DisableAnimationsStep)
    assert_instance_of Dotfiles::Step::DisableAnimationsStep, step
  end

  def test_runs_defaults_write_commands_for_all_settings
    step = create_step(Dotfiles::Step::DisableAnimationsStep)
    step.run

    assert @fake_system.received_operation?(:execute, "defaults write -g NSAutomaticWindowAnimationsEnabled -int 0", {quiet: true})
    assert @fake_system.received_operation?(:execute, "defaults write -g NSWindowResizeTime -float 0.001", {quiet: true})
    assert @fake_system.received_operation?(:execute, "defaults write com.apple.dock launchanim -int 0", {quiet: true})
    assert @fake_system.received_operation?(:execute, "defaults write com.apple.dock autohide-time-modifier -float 0.4", {quiet: true})
    assert @fake_system.received_operation?(:execute, "defaults write com.apple.finder DisableAllAnimations -int 1", {quiet: true})
  end

  def test_restarts_dock_and_finder
    step = create_step(Dotfiles::Step::DisableAnimationsStep)
    step.run

    assert @fake_system.received_operation?(:execute, "killall Dock", {quiet: true})
    assert @fake_system.received_operation?(:execute, "killall Finder", {quiet: true})
  end

  def test_complete_when_all_settings_match
    step = create_step(Dotfiles::Step::DisableAnimationsStep)
    stub_default_outputs
    assert step.complete?
  end

  def test_incomplete_when_any_setting_differs
    step = create_step(Dotfiles::Step::DisableAnimationsStep)
    stub_default_outputs
    @fake_system.stub_command("defaults read -g NSAutomaticWindowAnimationsEnabled", "1", exit_status: 0)
    refute step.complete?
  end

  def test_incomplete_when_setting_missing
    step = create_step(Dotfiles::Step::DisableAnimationsStep)
    @fake_system.stub_command("defaults read -g NSAutomaticWindowAnimationsEnabled", "", exit_status: 1)
    refute step.complete?
  end

  def test_update_reads_current_settings_and_writes_to_config
    step = create_step(Dotfiles::Step::DisableAnimationsStep)

    @fake_system.stub_command("defaults read -g NSAutomaticWindowAnimationsEnabled", "1", exit_status: 0)
    @fake_system.stub_command("defaults read -g NSWindowResizeTime", "0.002", exit_status: 0)
    @fake_system.stub_command("defaults read com.apple.dock launchanim", "1", exit_status: 0)
    @fake_system.stub_command("defaults read com.apple.dock autohide-time-modifier", "0.5", exit_status: 0)
    @fake_system.stub_command("defaults read com.apple.finder DisableAllAnimations", "0", exit_status: 0)

    step.update
    write_op = @fake_system.operations.find { |op| op[0] == :write_file && op[1] == "#{@dotfiles_dir}/config/animations.yml" }
    assert write_op, "Expected write_file operation to #{@dotfiles_dir}/config/animations.yml"
    written_content = write_op[2]
    parsed = YAML.safe_load(written_content)

    assert_equal 1, parsed["animation_settings"]["NSGlobalDomain"]["NSAutomaticWindowAnimationsEnabled"]
    assert_equal 0.002, parsed["animation_settings"]["NSGlobalDomain"]["NSWindowResizeTime"]
    assert_equal 1, parsed["animation_settings"]["com.apple.dock"]["launchanim"]
    assert_equal 0.5, parsed["animation_settings"]["com.apple.dock"]["autohide-time-modifier"]
    assert_equal 0, parsed["animation_settings"]["com.apple.finder"]["DisableAllAnimations"]
  end

  def test_update_only_updates_existing_keys
    step = create_step(Dotfiles::Step::DisableAnimationsStep)
    stub_default_outputs
    step.update
    read_operations = @fake_system.operations.select { |op| op[0] == :execute && op[1].start_with?("defaults read") }
    assert_equal 5, read_operations.size
  end
end
