require "test_helper"
require "open3"

class ExecutorWatchTest < Minitest::Test
  def test_completion_delivery_and_session_lifecycle
    tests = File.expand_path("../../executor_watch*_test.mjs", __dir__)
    output, status = Open3.capture2e("node", "--test", tests)
    assert status.success?, output
  end
end
