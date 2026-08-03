require "test_helper"

class FakeSystemAdapterTest < Minitest::Test
  def test_execute_and_execute_bang_return_the_unstubbed_default
    [:execute, :execute!].each do |method|
      adapter = FakeSystemAdapter.new

      output, status = adapter.public_send(method, "missing", quiet: false)

      assert_empty output
      assert_equal 0, status
      assert_equal [[method, "missing", {quiet: false}]], adapter.operations
      assert_equal [0], adapter.exit_statuses
    end
  end

  def test_execute_uses_normalized_lookup_and_returns_a_failed_result
    @fake_system.stub_command("tool 2>/dev/null", "  failed\n", exit_status: 7)

    output, status = @fake_system.execute(["tool"], quiet: false)

    assert_equal "failed", output
    assert_equal 7, status
    assert_equal [[:execute, ["tool"], {quiet: false}]], @fake_system.operations
    assert_equal [7], @fake_system.exit_statuses
  end

  def test_execute_bang_uses_normalized_lookup_and_returns_a_successful_result
    @fake_system.stub_command("tool 2>/dev/null", "  done\n")

    output, status = @fake_system.execute!(["tool"])

    assert_equal "done", output
    assert_equal 0, status
    assert_equal [[:execute!, ["tool"], {quiet: true}]], @fake_system.operations
    assert_equal [0], @fake_system.exit_statuses
  end

  def test_execute_bang_records_failure_before_raising_exact_error
    @fake_system.stub_command(["tool", "two words"], "  failed\n", exit_status: 7)

    error = assert_raises(RuntimeError) do
      @fake_system.execute!(["tool", "two words"], quiet: false)
    end

    assert_equal "Command failed: tool two\\ words\nOutput:   failed\n", error.message
    assert_equal [[:execute!, ["tool", "two words"], {quiet: false}]], @fake_system.operations
    assert_equal [7], @fake_system.exit_statuses
  end
end
