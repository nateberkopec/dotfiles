require "test_helper"

class ConfigTest < Minitest::Test
  def setup
    super
    @fixtures_dir = File.expand_path("../fixtures", __dir__)
  end

  def test_debian_desktop_apps_default_to_configured_apps
    config = Dotfiles::Config.new(@fixtures_dir)

    assert_equal ["example", "other"], config.debian_desktop_apps.map { |app| app["name"] }
  end

  def test_debian_desktop_apps_default_to_empty
    assert_empty Dotfiles::Config.new("/nonexistent/dir").debian_desktop_apps
  end

  def test_fetch_returns_config_value
    config = Dotfiles::Config.new(@fixtures_dir)

    assert_equal ["fish/config.fish", "fish/functions/"], config.fetch("config_directory_items")
  end

  def test_fetch_returns_default_for_missing_key
    config = Dotfiles::Config.new(@fixtures_dir)

    assert_equal "default", config.fetch("nonexistent", "default")
  end

  def test_bracket_accessor_returns_config_value
    config = Dotfiles::Config.new(@fixtures_dir)

    assert_equal ["fish/config.fish", "fish/functions/"], config["config_directory_items"]
  end
end
