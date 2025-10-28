require "test_helper"

class SyncConfigDirectoryStepTest < Minitest::Test
  def setup
    super
    @real_dotfiles_dir = File.expand_path("../../..", __dir__)
  end

  def test_step_exists
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep)
    assert_instance_of Dotfiles::Step::SyncConfigDirectoryStep, step
  end

  def test_syncs_files
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep, dotfiles_dir: @real_dotfiles_dir)
    @fake_system.stub_file_content("#{@real_dotfiles_dir}/files/config/fish/config.fish", "fish config")

    step.run

    cp_operations = @fake_system.operations.select { |op| op[0] == :cp }
    assert cp_operations.size > 0, "Expected at least one cp operation"
  end

  def test_complete_when_all_files_match
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep, dotfiles_dir: @real_dotfiles_dir)

    # Stub all actual files that exist in the repo
    Dir.glob("#{@real_dotfiles_dir}/files/config/**/*").each do |source_file|
      next unless File.file?(source_file)
      relative_path = source_file.sub("#{@real_dotfiles_dir}/files/config/", "")
      content = "content_#{relative_path}"
      @fake_system.stub_file_content(source_file, content)
      @fake_system.stub_file_content("#{@home}/.config/#{relative_path}", content)
    end

    assert step.complete?
  end

  def test_not_complete_when_files_dont_match
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep, dotfiles_dir: @real_dotfiles_dir)
    @fake_system.stub_file_content("#{@real_dotfiles_dir}/files/config/fish/config.fish", "new fish config")
    @fake_system.stub_file_content("#{@home}/.config/fish/config.fish", "old fish config")

    refute step.complete?
  end

  def test_not_complete_when_files_missing
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep, dotfiles_dir: @real_dotfiles_dir)
    @fake_system.stub_file_content("#{@real_dotfiles_dir}/files/config/fish/config.fish", "fish config")

    refute step.complete?
  end

  def test_update_is_callable
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep, dotfiles_dir: @real_dotfiles_dir)

    # Stub all actual files so update can run
    Dir.glob("#{@real_dotfiles_dir}/files/config/**/*").each do |source_file|
      next unless File.file?(source_file)
      relative_path = source_file.sub("#{@real_dotfiles_dir}/files/config/", "")
      @fake_system.stub_file_content(source_file, "content")
      @fake_system.stub_file_content("#{@home}/.config/#{relative_path}", "content")
    end

    # Should not raise
    step.update
  end

  def test_update_skips_unchanged_files
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep, dotfiles_dir: @real_dotfiles_dir)
    @fake_system.stub_file_content("#{@home}/.config/fish/config.fish", "same content")
    @fake_system.stub_file_content("#{@real_dotfiles_dir}/files/config/fish/config.fish", "same content")

    step.update

    refute @fake_system.received_operation?(:cp, "#{@home}/.config/fish/config.fish", "#{@real_dotfiles_dir}/files/config/fish/config.fish")
  end

  def test_syncs_multiple_items
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep, dotfiles_dir: @real_dotfiles_dir)
    @fake_system.stub_file_content("#{@real_dotfiles_dir}/files/config/fish/config.fish", "fish config")
    @fake_system.stub_file_content("#{@real_dotfiles_dir}/files/config/omf/theme", "omf theme")

    step.run

    cp_operations = @fake_system.operations.select { |op| op[0] == :cp }
    assert cp_operations.size > 0, "Expected multiple cp operations"
  end

  def test_creates_parent_directories_when_syncing
    step = create_step(Dotfiles::Step::SyncConfigDirectoryStep, dotfiles_dir: @real_dotfiles_dir)
    @fake_system.stub_file_content("#{@real_dotfiles_dir}/files/config/fish/config.fish", "fish config")

    step.run

    assert @fake_system.received_operation?(:mkdir_p, "#{@home}/.config/fish")
  end
end
