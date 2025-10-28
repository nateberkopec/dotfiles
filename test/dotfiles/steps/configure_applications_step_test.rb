require "test_helper"

class ConfigureApplicationsStepTest < Minitest::Test
  def setup
    super
  end

  def test_step_exists
    step = create_step(Dotfiles::Step::ConfigureApplicationsStep)
    assert_instance_of Dotfiles::Step::ConfigureApplicationsStep, step
  end

  def test_complete_when_all_files_match
    step = create_step(Dotfiles::Step::ConfigureApplicationsStep, dotfiles_dir: @fixtures_dir)
    stub_default_paths(step)
    @fake_system.stub_file_content("#{@fixtures_dir}/files/ghostty/config", "ghostty config")
    @fake_system.stub_file_content("/tmp/home/Library/Application Support/com.mitchellh.ghostty/config", "ghostty config")
    @fake_system.stub_file_content("#{@fixtures_dir}/files/aerospace/.aerospace.toml", "aerospace config")
    @fake_system.stub_file_content("/tmp/home/.aerospace.toml", "aerospace config")
    @fake_system.stub_file_content("#{@fixtures_dir}/files/git/.gitconfig", "git config")
    @fake_system.stub_file_content("/tmp/home/.gitconfig", "git config")

    assert step.complete?
  end

  def test_not_complete_when_files_dont_match
    step = create_step(Dotfiles::Step::ConfigureApplicationsStep, dotfiles_dir: @fixtures_dir)
    stub_default_paths(step)
    @fake_system.stub_file_content("#{@fixtures_dir}/files/ghostty/config", "ghostty config")
    @fake_system.stub_file_content("/tmp/home/Library/Application Support/com.mitchellh.ghostty/config", "old ghostty config")
    @fake_system.stub_file_content("#{@fixtures_dir}/files/aerospace/.aerospace.toml", "aerospace config")
    @fake_system.stub_file_content("/tmp/home/.aerospace.toml", "aerospace config")
    @fake_system.stub_file_content("#{@fixtures_dir}/files/git/.gitconfig", "git config")
    @fake_system.stub_file_content("/tmp/home/.gitconfig", "git config")

    refute step.complete?
  end

  def test_not_complete_when_files_missing
    step = create_step(Dotfiles::Step::ConfigureApplicationsStep, dotfiles_dir: @fixtures_dir)
    refute step.complete?
  end

  def test_update_copies_changed_files
    step = create_step(Dotfiles::Step::ConfigureApplicationsStep, dotfiles_dir: @fixtures_dir)
    stub_default_paths(step)
    @fake_system.stub_file_content("/tmp/home/Library/Application Support/com.mitchellh.ghostty/config", "updated ghostty")
    @fake_system.stub_file_content("#{@fixtures_dir}/files/ghostty/config", "old ghostty")
    @fake_system.stub_file_content("/tmp/home/.aerospace.toml", "updated aerospace")
    @fake_system.stub_file_content("#{@fixtures_dir}/files/aerospace/.aerospace.toml", "old aerospace")
    @fake_system.stub_file_content("/tmp/home/.gitconfig", "updated git")
    @fake_system.stub_file_content("#{@fixtures_dir}/files/git/.gitconfig", "old git")

    step.update

    assert_equal "updated ghostty", @fake_system.filesystem[File.expand_path("#{@fixtures_dir}/files/ghostty/config")]
    assert_equal "updated aerospace", @fake_system.filesystem[File.expand_path("#{@fixtures_dir}/files/aerospace/.aerospace.toml")]
    assert_equal "updated git", @fake_system.filesystem[File.expand_path("#{@fixtures_dir}/files/git/.gitconfig")]
  end

  def test_update_skips_unchanged_files
    step = create_step(Dotfiles::Step::ConfigureApplicationsStep, dotfiles_dir: @fixtures_dir)
    stub_default_paths(step)
    @fake_system.stub_file_content("/tmp/home/Library/Application Support/com.mitchellh.ghostty/config", "same ghostty")
    @fake_system.stub_file_content("#{@fixtures_dir}/files/ghostty/config", "same ghostty")
    @fake_system.stub_file_content("/tmp/home/.aerospace.toml", "same aerospace")
    @fake_system.stub_file_content("#{@fixtures_dir}/files/aerospace/.aerospace.toml", "same aerospace")
    @fake_system.stub_file_content("/tmp/home/.gitconfig", "same git")
    @fake_system.stub_file_content("#{@fixtures_dir}/files/git/.gitconfig", "same git")

    step.update

    refute @fake_system.received_operation?(:cp)
  end

  def test_update_handles_missing_files
    step = create_step(Dotfiles::Step::ConfigureApplicationsStep, dotfiles_dir: @fixtures_dir)
    step.update
    refute @fake_system.received_operation?(:cp)
  end
end
