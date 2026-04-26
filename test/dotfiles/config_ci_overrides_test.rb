require "test_helper"

class ConfigCiOverridesTest < Minitest::Test
  def setup
    super
    @fixtures_dir = File.expand_path("../fixtures", __dir__)
  end

  def test_ci_package_overrides_use_csv_values
    with_env("BREW_CI_PACKAGES" => "duti", "DEBIAN_CI_PACKAGES" => "trash-cli") do
      config = Dotfiles::Config.new(@fixtures_dir)

      assert_equal ["duti"], config.brew_packages
      assert_equal ["trash-cli"], config.debian_packages
    end
  end

  def test_ci_empty_overrides_disable_optional_installers
    with_env(
      "DEBIAN_CI_NON_APT_PACKAGES" => "",
      "DEBIAN_CI_SNAP_PACKAGES" => "",
      "DEBIAN_CI_SOURCES" => ""
    ) do
      config = Dotfiles::Config.new(@fixtures_dir)

      assert_equal [], config.debian_non_apt_packages
      assert_equal [], config.debian_snap_packages
      assert_equal [], config.debian_sources
    end
  end

  def test_debian_ci_sources_filters_by_source_name
    with_env("DEBIAN_CI_SOURCES" => "example") do
      config = Dotfiles::Config.new(@fixtures_dir)

      assert_equal ["example"], config.debian_sources.map { |source| source["name"] }
    end
  end

  def test_brew_ci_applications_filters_by_cask
    with_env("BREW_CI_APPLICATIONS" => "1password") do
      config = Dotfiles::Config.new(@fixtures_dir)
      apps = [{"name" => "1Password", "brew_cask" => "1password"}, {"name" => "Dia", "brew_cask" => "dia"}]
      config.applications = apps

      assert_equal ["1Password"], config.applications.map { |app| app["name"] }
    end
  end
end
