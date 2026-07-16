require "test_helper"

class UpgradeBrewPackagesStepTest < Minitest::Test
  include ConfigFixtureHelper
  include SystemAssertions

  def test_complete_returns_true
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    assert step.complete?
  end

  def test_should_run_for_outdated_managed_packages
    write_config("config", "packages" => {"fish" => {"brew" => "fish"}, "gh" => {"brew" => "gh"}})
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    @fake_system.stub_command(brew_outdated_command, "bat\nfish\ngh\n")

    assert step.should_run?
  end

  def test_should_not_run_when_only_unmanaged_packages_are_outdated
    write_config("config", "packages" => {"fish" => {"brew" => "fish"}})
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    @fake_system.stub_command(brew_outdated_command, "bat\n")

    refute step.should_run?
  end

  def test_should_not_run_when_packages_up_to_date
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    @fake_system.stub_command(brew_outdated_command, "")

    refute step.should_run?
  end

  def test_run_upgrades_and_cleans_outdated_managed_packages
    write_config("config", "packages" => {"fish" => {"brew" => "fish"}, "gh" => {"brew" => "gh"}})
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    @fake_system.stub_command(brew_outdated_command, "bat\nfish\ngh\n")
    @fake_system.stub_command(brew_upgrade_command("fish", "gh"), "")
    @fake_system.stub_command(brew_cleanup_command("fish", "gh"), "")

    step.should_run?
    step.run

    assert_executed(brew_upgrade_command("fish", "gh"))
    assert_executed(brew_cleanup_command("fish", "gh"))
  end

  def test_complete_reports_upgrade_failure
    write_config("config", "packages" => {"fish" => {"brew" => "fish"}})
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    @fake_system.stub_command(brew_outdated_command, "fish\n")
    @fake_system.stub_command(brew_upgrade_command("fish"), "boom", exit_status: 1)

    step.should_run?
    step.run

    refute step.complete?
    assert_includes step.errors.join("\n"), "brew upgrade fish failed"
  end

  def test_uses_quiet_homebrew_environment
    step = create_step(Dotfiles::Step::UpgradeBrewPackagesStep)
    @fake_system.stub_command(brew_outdated_command, "")

    step.should_run?

    assert @fake_system.received_operation?(:execute, brew_outdated_command, {quiet: true})
  end

  private

  def brew_outdated_command
    brew_command("outdated", "--formula", "--quiet")
  end

  def brew_upgrade_command(*packages)
    brew_command("upgrade", *packages)
  end

  def brew_cleanup_command(*packages)
    brew_command("cleanup", *packages)
  end

  def brew_command(*args)
    [{"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", *args]
  end
end
