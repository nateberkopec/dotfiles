require "test_helper"
require "open3"

class ToksecTest < Minitest::Test
  def test_human_turn_measurements
    output, status = Open3.capture2e("node", "--test", "#{__dir__}/../../toksec_test.mjs")
    assert status.success?, output
  end
end
