require "test_helper"
require "json"

class PiSettingsTest < Minitest::Test
  SETTINGS = File.expand_path("../../files/home/.pi/agent/settings.json", __dir__)

  def test_pi_web_providers_uses_mainline_package
    packages = JSON.parse(Dotfiles::SystemAdapter.new.read_file(SETTINGS)).fetch("packages")

    assert_includes packages, "npm:pi-web-providers"
    refute_includes packages, "git:github.com/nateberkopec/pi-web-providers"
  end
end
