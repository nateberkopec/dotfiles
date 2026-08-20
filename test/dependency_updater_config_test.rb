require "test_helper"
require "yaml"

# standard:disable Dotfiles/BanFileSystemClasses
class DependencyUpdaterConfigTest < Minitest::Test
  def test_every_managed_cask_has_an_observation_baseline
    managed = YAML.safe_load_file(config_path).fetch("brew_casks")
    observed = YAML.safe_load_file(updater_path).fetch("observed_casks").keys

    assert_empty managed - observed
    assert_empty observed - managed
  end

  private

  def config_path
    File.expand_path("../config/config.yml", __dir__)
  end

  def updater_path
    File.expand_path("../config/dependency-updater.yml", __dir__)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
