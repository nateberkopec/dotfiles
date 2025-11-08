require "test_helper"

class ConfigureScreenshotsStepTest < Minitest::Test
  def setup
    super
    stub_screenshots_config
  end

  def stub_screenshots_config
    config_content = <<~YAML
      screenshot_settings:
        com.apple.screencapture:
          location: ~/Documents/Inbox
    YAML

    @fake_system.stub_file_content("#{@dotfiles_dir}/config/screenshots.yml", config_content)
  end

  def test_step_exists
    step = create_step(Dotfiles::Step::ConfigureScreenshotsStep)
    assert_instance_of Dotfiles::Step::ConfigureScreenshotsStep, step
  end

  def test_depends_on_create_standard_folders_step
    dependencies = Dotfiles::Step::ConfigureScreenshotsStep.depends_on
    assert_includes dependencies, Dotfiles::Step::CreateStandardFoldersStep
  end

  def test_runs_defaults_write_command_for_location
    step = create_step(Dotfiles::Step::ConfigureScreenshotsStep)
    step.run

    assert @fake_system.received_operation?(:execute, "defaults write com.apple.screencapture location -string ~/Documents/Inbox", {quiet: true})
  end

  def test_restarts_system_ui_server
    step = create_step(Dotfiles::Step::ConfigureScreenshotsStep)
    step.run

    assert @fake_system.received_operation?(:execute, "killall SystemUIServer", {quiet: true})
  end

  def test_complete_when_location_matches
    step = create_step(Dotfiles::Step::ConfigureScreenshotsStep)
    @fake_system.stub_command("defaults read com.apple.screencapture location", "~/Documents/Inbox", exit_status: 0)

    assert step.complete?
  end

  def test_incomplete_when_location_differs
    step = create_step(Dotfiles::Step::ConfigureScreenshotsStep)
    @fake_system.stub_command("defaults read com.apple.screencapture location", "~/Desktop", exit_status: 0)

    refute step.complete?
  end

  def test_incomplete_when_location_not_set
    step = create_step(Dotfiles::Step::ConfigureScreenshotsStep)
    @fake_system.stub_command("defaults read com.apple.screencapture location", "", exit_status: 1)

    refute step.complete?
  end

  def test_update_reads_current_location_and_writes_to_config
    step = create_step(Dotfiles::Step::ConfigureScreenshotsStep)
    @fake_system.stub_command("defaults read com.apple.screencapture location", "~/Documents/Screenshots", exit_status: 0)

    step.update
    write_op = @fake_system.operations.find { |op| op[0] == :write_file && op[1] == "#{@dotfiles_dir}/config/screenshots.yml" }
    assert write_op, "Expected write_file operation to #{@dotfiles_dir}/config/screenshots.yml"
  end
end
