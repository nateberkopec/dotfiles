require "test_helper"

class CloneDotfilesStepTest < Minitest::Test
  def test_clones_when_directory_missing
    step = create_step(Dotfiles::Step::CloneDotfilesStep)
    dotfiles_dir = step.instance_variable_get(:@config).dotfiles_dir
    @fake_system.stub_command_output("git clone https://github.com/test/dotfiles.git #{dotfiles_dir}", "")

    refute step.complete?
    step.run

    assert @fake_system.received_operation?(:execute, "git clone https://github.com/test/dotfiles.git #{dotfiles_dir}", {quiet: true})
  end

  def test_pulls_when_directory_exists
    dotfiles_dir = @config.dotfiles_dir
    @fake_system.stub_file_content("#{dotfiles_dir}/.git/config", "[remote \"origin\"]")
    @fake_system.stub_command_output("git pull", "Already up to date.")

    step = create_step(Dotfiles::Step::CloneDotfilesStep)
    step.run

    assert @fake_system.received_operation?(:chdir, dotfiles_dir)
    assert @fake_system.received_operation?(:execute, "git pull", {quiet: true})
  end

  def test_complete_when_git_directory_exists
    dotfiles_dir = @config.dotfiles_dir
    @fake_system.stub_file_content("#{dotfiles_dir}/.git/config", "[remote \"origin\"]")

    step = create_step(Dotfiles::Step::CloneDotfilesStep)
    assert step.complete?
  end

  def test_incomplete_when_git_directory_missing
    dotfiles_dir = @config.dotfiles_dir
    @fake_system.stub_file_content("#{dotfiles_dir}/README.md", "# Dotfiles")

    step = create_step(Dotfiles::Step::CloneDotfilesStep)
    refute step.complete?
  end
end
