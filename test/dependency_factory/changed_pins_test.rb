require "test_helper"
require_relative "../../tools/ci/dependency_factory"

class DependencyFactoryChangedPinsTest < Minitest::Test
  def test_reports_changed_pins_by_canonical_name_and_flags_a_changed_lock
    before = {
      "files/home/.config/mise/config.toml" => "[tools]\ngh = \"2.97.0\"\nfd = \"10.4.2\"\n",
      "files/home/.pi/agent/settings.json" => '{"packages": ["npm:pi-ding@0.2.2"]}',
      "Gemfile.lock" => "GEM\n  specs:\n    json (2.18.0)\n\nPLATFORMS\n  ruby\n\nBUNDLED WITH\n   2.7.0\n"
    }
    after = before.merge(
      "files/home/.config/mise/config.toml" => "[tools]\ngh = \"2.98.0\"\nfd = \"10.4.2\"\n",
      "Gemfile.lock" => "GEM\n  specs:\n    json (2.21.2)\n\nPLATFORMS\n  ruby\n\nBUNDLED WITH\n   2.7.0\n"
    )
    pins = DependencyFactory::ChangedPins.new(base: "abc", show: ->(_base, path) { before.fetch(path, "") }, read: ->(path) { after.fetch(path, "") })

    assert_equal({"gh" => ["2.97.0", "2.98.0"], "Gemfile.lock" => ["changed", "changed"], "json" => ["2.18.0", "2.21.2"]}, pins.changes)
  end
end
