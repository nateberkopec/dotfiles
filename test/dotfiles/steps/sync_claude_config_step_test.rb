require "test_helper"

class SyncClaudeConfigStepTest < Minitest::Test
  def setup
    super
    @step = create_step(Dotfiles::Step::SyncClaudeConfigStep)
    @step.config.paths = claude_paths
  end

  def claude_paths
    {
      "application_paths" => {
        "claude_config" => "#{@home}/.claude/CLAUDE.md"
      },
      "dotfiles_sources" => {
        "claude_config" => ".claude/CLAUDE.md"
      }
    }
  end

  def test_complete_when_files_match
    source = File.join(@dotfiles_dir, ".claude/CLAUDE.md")
    dest = "#{@home}/.claude/CLAUDE.md"
    @fake_system.stub_file_content(source, "# Config")
    @fake_system.stub_file_content(dest, "# Config")

    assert @step.complete?
  end

  def test_not_complete_when_source_missing
    refute @step.complete?
    assert_includes @step.errors, "Claude config source does not exist at #{@dotfiles_dir}/.claude/CLAUDE.md"
  end

  def test_not_complete_when_files_dont_match
    source = File.join(@dotfiles_dir, ".claude/CLAUDE.md")
    dest = "#{@home}/.claude/CLAUDE.md"
    @fake_system.stub_file_content(source, "# Config")
    @fake_system.stub_file_content(dest, "# Different")

    refute @step.complete?
    assert_includes @step.errors, "Claude config is not synced"
  end

  def test_run_copies_config_file
    source = File.join(@dotfiles_dir, ".claude/CLAUDE.md")
    dest = "#{@home}/.claude/CLAUDE.md"
    @fake_system.stub_file_content(source, "# Config")

    @step.run

    assert @fake_system.received_operation?(:mkdir_p, "#{@home}/.claude")
    assert @fake_system.received_operation?(:cp, source, dest)
  end

  def test_update_copies_from_system_to_dotfiles
    source = "#{@home}/.claude/CLAUDE.md"
    dest = File.join(@dotfiles_dir, ".claude/CLAUDE.md")
    @fake_system.stub_file_content(source, "# Updated config")

    @step.update

    assert @fake_system.received_operation?(:mkdir_p, File.join(@dotfiles_dir, ".claude"))
    assert @fake_system.received_operation?(:cp, source, dest)
  end
end
