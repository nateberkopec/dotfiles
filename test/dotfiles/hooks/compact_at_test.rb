require "test_helper"
require "open3"

class CompactAtTest < Minitest::Test
  def test_context_window_clamp_and_session_override
    output, status = Open3.capture2e("node", "--test", "#{__dir__}/../../compact_at_test.mjs")
    assert status.success?, output
  end
end
