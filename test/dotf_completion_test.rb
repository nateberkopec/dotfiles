require "test_helper"
require "open3"
require "shellwords"

class DotfCompletionTest < Minitest::Test
  ROOT_DIR = File.expand_path("..", __dir__)
  DOTF = File.join(ROOT_DIR, "bin", "dotf")
  FISH_COMPLETION_DIR = File.join(ROOT_DIR, "files", "home", ".config", "fish", "completions")

  def test_completion_command_lists_every_public_dispatch_command
    completion_commands = dotf_completion_commands

    public_dispatch_commands.each do |command|
      assert_includes completion_commands, command
    end
  end

  def test_fish_completion_suggests_dotf_commands
    skip "fish is not installed" unless fish_available?

    stdout, stderr, status = Open3.capture3(
      {"PATH" => "#{File.dirname(DOTF)}:#{ENV.fetch("PATH", "")}"},
      "fish",
      "--no-config",
      "-c",
      "set -g fish_complete_path #{Shellwords.escape(FISH_COMPLETION_DIR)}; complete -C 'dotf '"
    )

    assert status.success?, stderr
    fish_completions = stdout.lines.map(&:chomp)

    dotf_completion_lines.each do |line|
      assert_includes fish_completions, line
    end
  end

  private

  def dotf_completion_commands
    dotf_completion_lines.map { |line| line.split("\t", 2).first }
  end

  def dotf_completion_lines
    stdout, stderr, status = Open3.capture3(DOTF, "__commands")
    assert status.success?, stderr
    stdout.lines.map(&:chomp)
  end

  def fish_available?
    _stdout, _stderr, status = Open3.capture3("fish", "--version")
    status.success?
  rescue Errno::ENOENT
    false
  end

  def public_dispatch_commands
    source = IO.read(DOTF)
    command_block = source[/case "\$1" in\n(.*?)\n        \*\)/m, 1]
    refute_nil command_block

    command_block.scan(/^\s+([^\s)]+)\)/).flatten.flat_map { |label| label.split("|") }
      .reject { |command| command.start_with?("-", "__") }
  end
end
