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

  def test_loads_paths_from_yaml
    config = Dotfiles::Config.new(@fixtures_dir)
    paths = config.paths

    assert_equal "~/.config/fish", paths["home_paths"]["fish_config_dir"]
    assert_equal "files/fish/config.fish", paths["dotfiles_sources"]["fish_config"]
  end

  def test_dotfiles_repo_from_config
    config = Dotfiles::Config.new(@fixtures_dir)
    assert_equal "https://github.com/test/dotfiles.git", config.dotfiles_repo
  end

  def test_dotfiles_repo_default_fallback
    require "tmpdir"
    Dir.mktmpdir do |dir|
      config = Dotfiles::Config.new(dir)
      assert_equal "https://github.com/nateberkopec/dotfiles.git", config.dotfiles_repo
    end
  end

  def test_missing_config_file_returns_empty_hash
    require "tmpdir"
    Dir.mktmpdir do |dir|
      config = Dotfiles::Config.new(dir)
      assert_equal({}, config.packages)
      assert_equal({}, config.paths)
    end
  end
end
