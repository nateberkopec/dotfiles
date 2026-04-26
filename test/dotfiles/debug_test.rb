require "test_helper"
require "tmpdir"

# standard:disable Dotfiles/BanFileSystemClasses
class DotfilesDebugTest < Minitest::Test
  TIMESTAMPED_LINE = /\A\[\d{2}:\d{2}:\d{2}\.\d{3}\] /

  def setup
    super
    Dotfiles.log_file = nil
  end

  def teardown
    Dotfiles.log_file = nil
    super
  end

  def test_debug_writes_timestamped_message_to_log_file
    Dir.mktmpdir("dotfiles-debug-test") do |tmpdir|
      log_file = File.join(tmpdir, "debug.log")
      Dotfiles.log_file = log_file

      Dotfiles.debug("hello")

      assert_match(/\A\[\d{2}:\d{2}:\d{2}\.\d{3}\] hello\n\z/, File.read(log_file))
    end
  end

  def test_debug_prints_timestamped_message_when_debug_is_true
    with_env("DEBUG" => "true") do
      stdout, = capture_io do
        Dotfiles.debug("hello")
      end

      assert_match(/\A\[\d{2}:\d{2}:\d{2}\.\d{3}\] hello\n\z/, stdout)
    end
  end

  def test_debug_timestamps_each_line_in_multiline_messages
    Dir.mktmpdir("dotfiles-debug-test") do |tmpdir|
      log_file = File.join(tmpdir, "debug.log")
      Dotfiles.log_file = log_file

      Dotfiles.debug("first\nsecond")

      lines = File.readlines(log_file, chomp: true)
      assert_equal 2, lines.size
      assert lines.all? { |line| line.match?(TIMESTAMPED_LINE) }
      assert_match(/ first\z/, lines.first)
      assert_match(/ second\z/, lines.last)
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
