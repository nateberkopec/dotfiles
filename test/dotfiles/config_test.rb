require "test_helper"

class ConfigTest < Minitest::Test
  def setup
    super
    @fixtures_dir = File.expand_path("../fixtures", __dir__)
  end

  def test_loads_packages_from_yaml
    config = Dotfiles::Config.new(@fixtures_dir)
    packages = config.packages

    assert_equal ["fish", "git"], packages["brew"]["packages"]
    assert_equal ["firefox", "dropbox"], packages["brew"]["casks"]
  end

  def test_dotfiles_repo_from_config
    config = Dotfiles::Config.new(@fixtures_dir)
    assert_equal "https://github.com/test/dotfiles.git", config.dotfiles_repo
  end

  def test_dotfiles_repo_default_fallback
    config = Dotfiles::Config.new("/nonexistent/dir")
    assert_equal "https://github.com/nateberkopec/dotfiles.git", config.dotfiles_repo
  end

  def test_missing_config_file_returns_empty
    config = Dotfiles::Config.new("/nonexistent/dir")
    assert_equal({"brew" => {}, "applications" => []}, config.packages)
  end

  def test_fetch_returns_config_value
    config = Dotfiles::Config.new(@fixtures_dir)
    assert_equal "https://github.com/test/dotfiles.git", config.fetch("dotfiles_repo")
  end

  def test_fetch_returns_default_for_missing_key
    config = Dotfiles::Config.new(@fixtures_dir)
    assert_equal "default", config.fetch("nonexistent", "default")
  end

  def test_bracket_accessor_returns_config_value
    config = Dotfiles::Config.new(@fixtures_dir)
    assert_equal "https://github.com/test/dotfiles.git", config["dotfiles_repo"]
  end
end
