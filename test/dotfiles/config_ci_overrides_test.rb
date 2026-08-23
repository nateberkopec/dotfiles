require "test_helper"

class ConfigCiOverridesTest < Minitest::Test
  def setup
    super
    @fixtures_dir = File.expand_path("../fixtures", __dir__)
  end

  def test_debian_ci_desktop_apps_filters_by_name
    with_env("DEBIAN_CI_DESKTOP_APPS" => "other") do
      config = Dotfiles::Config.new(@fixtures_dir)

      assert_equal ["other"], config.debian_desktop_apps.map { |app| app["name"] }
    end
  end
end
