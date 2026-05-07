require "test_helper"
require_relative "../../support/wallpaper_step_helper"

class ConfigureWallpaperStepTest < StepTestCase
  include WallpaperStepHelper

  step_class Dotfiles::Step::ConfigureWallpaperStep

  def test_depends_on_fish_and_brew_packages
    assert_equal(
      [Dotfiles::Step::InstallFishShellStep, Dotfiles::Step::InstallBrewPackagesStep],
      self.class.step_class.depends_on
    )
  end

  def test_skips_in_ci
    with_ci do
      refute step.should_run?
      assert step.complete?
    end
  end

  def test_should_run_when_splash_is_missing
    stub_splash_missing
    install_current_files
    stub_launchagent_loaded

    assert_should_run
  end

  def test_should_not_run_when_fully_installed
    stub_splash_on_path
    install_current_files
    stub_launchagent_loaded

    refute_should_run
  end

  def test_complete_when_all_installed
    stub_splash_on_path
    install_current_files
    stub_launchagent_loaded

    assert_complete
  end

  def test_incomplete_when_launchagent_unloaded
    stub_splash_on_path
    install_current_files
    stub_launchagent_unloaded

    assert_incomplete
  end
end
