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
    assert_equal ["fish", "git"], packages["debian"]["packages"]
  end

  def test_loads_debian_sources_from_yaml
    config = Dotfiles::Config.new(@fixtures_dir)

    assert_equal(
      [
        {
          "name" => "example",
          "repo" => "http://example.invalid/debian",
          "suite" => "stable",
          "components" => ["main"]
        }
      ],
      config.debian_sources
    )
  end

  def test_loads_debian_non_apt_packages_from_yaml
    config = Dotfiles::Config.new(@fixtures_dir)

    assert_equal(["starship"], config.debian_non_apt_packages)
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
    assert_equal(
      {
        "brew" => {"packages" => [], "casks" => []},
        "debian" => {"packages" => [], "sources" => []},
        "applications" => []
      },
      config.packages
    )
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

  def test_brew_ci_packages_overrides_config
    with_env("BREW_CI_PACKAGES" => "bat, ripgrep") do
      config = Dotfiles::Config.new(@fixtures_dir)
      assert_equal ["bat", "ripgrep"], config.brew_packages
    end
  end

  def test_brew_ci_casks_overrides_config
    with_env("BREW_CI_CASKS" => "ghostty, cursor") do
      config = Dotfiles::Config.new(@fixtures_dir)
      assert_equal ["ghostty", "cursor"], config.brew_casks
    end
  end

  def test_brew_ci_casks_empty_string_returns_empty_array
    with_env("BREW_CI_CASKS" => "") do
      config = Dotfiles::Config.new(@fixtures_dir)
      assert_equal [], config.brew_casks
    end
  end
end
