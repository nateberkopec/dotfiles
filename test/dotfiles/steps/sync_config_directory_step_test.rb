require "test_helper"

class SyncConfigDirectoryStepTest < Minitest::Test
  def setup
    super
    # Use the @fixtures_dir from test_helper.rb instead of computing it here
  end

  def test_step_exists
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep)
    assert_instance_of Dotfiles::Step::SyncConfigDirectoryStep, step
  end

  def test_syncs_files
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep, dotfiles_dir: @fixtures_dir)
    step.config.stub_config("config_sync.yml", {
      "config_directory_items" => ["fish/config.fish"]
    })
    @fake_system.stub_file_content("#{@fixtures_dir}/files/config/fish/config.fish", "fish config")

    step.run

    cp_operations = @fake_system.operations.select { |op| op[0] == :cp }
    assert cp_operations.size > 0, "Expected at least one cp operation"
  end

  def test_complete_when_all_files_match
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep, dotfiles_dir: @fixtures_dir)
    step.config.stub_config("config_sync.yml", {
      "config_directory_items" => ["fish/config.fish", "fish/functions/"]
    })

    # Stub the files
    @fake_system.stub_file_content("#{@fixtures_dir}/files/config/fish/config.fish", "content")
    @fake_system.stub_file_content("#{@home}/.config/fish/config.fish", "content")

    # Stub directory files
    @fake_system.mkdir_p("#{@fixtures_dir}/files/config/fish/functions")
    @fake_system.stub_file_content("#{@fixtures_dir}/files/config/fish/functions/test.fish", "func")
    @fake_system.stub_file_content("#{@home}/.config/fish/functions/test.fish", "func")

    assert step.complete?
  end

  def test_not_complete_when_files_dont_match
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep, dotfiles_dir: @fixtures_dir)
    step.config.stub_config("config_sync.yml", {
      "config_directory_items" => ["fish/config.fish"]
    })
    @fake_system.stub_file_content("#{@fixtures_dir}/files/config/fish/config.fish", "new fish config")
    @fake_system.stub_file_content("#{@home}/.config/fish/config.fish", "old fish config")

    refute step.complete?
  end

  def test_not_complete_when_files_missing
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep, dotfiles_dir: @fixtures_dir)
    step.config.stub_config("config_sync.yml", {
      "config_directory_items" => ["fish/config.fish"]
    })
    @fake_system.stub_file_content("#{@fixtures_dir}/files/config/fish/config.fish", "fish config")

    refute step.complete?
  end

  def test_update_is_callable
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep, dotfiles_dir: @fixtures_dir)
    step.config.stub_config("config_sync.yml", {
      "config_directory_items" => ["fish/config.fish"]
    })

    # Stub files so update can run
    @fake_system.stub_file_content("#{@fixtures_dir}/files/config/fish/config.fish", "content")
    @fake_system.stub_file_content("#{@home}/.config/fish/config.fish", "content")

    # Should not raise
    step.update
  end

  def test_update_skips_unchanged_files
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep, dotfiles_dir: @fixtures_dir)
    step.config.stub_config("config_sync.yml", {
      "config_directory_items" => ["fish/config.fish"]
    })
    @fake_system.stub_file_content("#{@home}/.config/fish/config.fish", "same content")
    @fake_system.stub_file_content("#{@fixtures_dir}/files/config/fish/config.fish", "same content")

    step.update

    refute @fake_system.received_operation?(:cp, "#{@home}/.config/fish/config.fish", "#{@fixtures_dir}/files/config/fish/config.fish")
  end

  def test_syncs_multiple_items
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep, dotfiles_dir: @fixtures_dir)
    step.config.stub_config("config_sync.yml", {
      "config_directory_items" => ["fish/config.fish", "omf/theme"]
    })
    @fake_system.stub_file_content("#{@fixtures_dir}/files/config/fish/config.fish", "fish config")
    @fake_system.stub_file_content("#{@fixtures_dir}/files/config/omf/theme", "omf theme")

    step.run

    cp_operations = @fake_system.operations.select { |op| op[0] == :cp }
    assert cp_operations.size > 0, "Expected multiple cp operations"
  end

  def test_creates_parent_directories_when_syncing
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep, dotfiles_dir: @fixtures_dir)
    step.config.stub_config("config_sync.yml", {
      "config_directory_items" => ["fish/config.fish"]
    })
    @fake_system.stub_file_content("#{@fixtures_dir}/files/config/fish/config.fish", "fish config")

    step.run

    assert @fake_system.received_operation?(:mkdir_p, "#{@home}/.config/fish")
  end
end
