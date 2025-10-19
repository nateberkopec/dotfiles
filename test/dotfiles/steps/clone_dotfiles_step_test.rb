require "test_helper"

class CloneDotfilesStepTest < Minitest::Test
  def test_clones_when_directory_missing
    step = create_step(Dotfiles::Step::CloneDotfilesStep)
    @fake_system.stub_command_output("git clone https://github.com/test/dotfiles.git /tmp/dotfiles", "")

    refute step.complete?
    step.run

    assert @fake_system.received_operation?(:execute, "git clone https://github.com/test/dotfiles.git /tmp/dotfiles", {quiet: true})
  end

  def test_pulls_when_directory_exists
    @fake_system.stub_file_content("/tmp/dotfiles/.git/config", "[remote \"origin\"]")
    @fake_system.stub_command_output("git pull", "Already up to date.")

    step = create_step(Dotfiles::Step::CloneDotfilesStep)
    step.run

    assert @fake_system.received_operation?(:chdir, "/tmp/dotfiles")
    assert @fake_system.received_operation?(:execute, "git pull", {quiet: true})
  end

  def test_complete_when_git_directory_exists
    @fake_system.stub_file_content("/tmp/dotfiles/.git/config", "[remote \"origin\"]")

    step = create_step(Dotfiles::Step::CloneDotfilesStep)
    assert step.complete?
  end

  def test_incomplete_when_git_directory_missing
    @fake_system.stub_file_content("/tmp/dotfiles/README.md", "# Dotfiles")

    step = create_step(Dotfiles::Step::CloneDotfilesStep)
    refute step.complete?
  end
end
