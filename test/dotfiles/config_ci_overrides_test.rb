require "test_helper"

class ConfigCiOverridesTest < Minitest::Test
  def setup
    super
    @fixtures_dir = File.expand_path("../fixtures", __dir__)
  end

  def test_ci_empty_overrides_disable_optional_installers
    with_env(
      "DEBIAN_CI_NON_APT_PACKAGES" => "",
      "DEBIAN_CI_DESKTOP_APPS" => ""
    ) do
      config = Dotfiles::Config.new(@fixtures_dir)

      assert_equal [], config.debian_non_apt_packages
      assert_equal [], config.debian_desktop_apps
    end
  end

  def test_debian_ci_desktop_apps_filters_by_name
    with_env("DEBIAN_CI_DESKTOP_APPS" => "example") do
      config = Dotfiles::Config.new(@fixtures_dir)

      assert_equal ["example"], config.debian_desktop_apps.map { |app| app["name"] }
    end
  end

  def test_debian_ci_non_apt_packages_use_csv_values
    with_env("DEBIAN_CI_NON_APT_PACKAGES" => "starship, droid") do
      config = Dotfiles::Config.new(@fixtures_dir)

      assert_equal ["starship", "droid"], config.debian_non_apt_packages
    end
  end
end
