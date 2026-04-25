require "test_helper"

class SystemAdapterTest < Minitest::Test
  class TestSystemAdapter < Dotfiles::SystemAdapter
    attr_reader :calls

    def initialize
      @calls = []
    end

    def execute_quiet(command)
      @calls << [:quiet, command]
      ["quiet", 0]
    end

    def execute_verbose(command)
      @calls << [:verbose, command]
      ["verbose", 0]
    end
  end

  def test_execute_uses_quiet_path_by_default
    adapter = TestSystemAdapter.new

    output, status = adapter.execute("echo hi")

    assert_equal ["quiet", 0], [output, status]
    assert_equal [[:quiet, "echo hi"]], adapter.calls
  end

  def test_execute_streams_output_when_debug_is_true
    adapter = TestSystemAdapter.new

    with_env("DEBUG" => "true") do
      output, status = adapter.execute("echo hi")

      assert_equal ["verbose", 0], [output, status]
    end

    assert_equal [[:verbose, "echo hi"]], adapter.calls
  end

  def test_execute_honors_explicit_verbose_calls
    adapter = TestSystemAdapter.new

    output, status = adapter.execute("echo hi", quiet: false)

    assert_equal ["verbose", 0], [output, status]
    assert_equal [[:verbose, "echo hi"]], adapter.calls
  end
end
