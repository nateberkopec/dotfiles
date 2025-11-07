require "test_helper"

class ConfigureDropboxStepTest < Minitest::Test
  def setup
    super
    @step = create_step(Dotfiles::Step::ConfigureDropboxStep)
  end

  def test_depends_on_install_brew_packages_step
    assert_equal [Dotfiles::Step::InstallBrewPackagesStep], Dotfiles::Step::ConfigureDropboxStep.depends_on
  end

  def test_should_run_when_dropbox_installed_but_not_configured
    stub_dropbox_installed
    refute_dropbox_configured

    assert @step.should_run?
  end

  def test_should_not_run_when_dropbox_not_installed
    refute_dropbox_installed

    refute @step.should_run?
  end

  def test_should_not_run_when_dropbox_already_configured
    stub_dropbox_installed
    stub_dropbox_configured

    refute @step.should_run?
  end

  def test_complete_when_dropbox_folder_exists
    stub_dropbox_configured

    assert @step.complete?
  end

  def test_incomplete_when_dropbox_folder_does_not_exist
    refute_dropbox_configured

    refute @step.complete?
  end

  def test_run_launches_dropbox_app
    stub_dropbox_installed

    @step.run

    assert @fake_system.received_operation?(:execute, "open -a Dropbox", {quiet: true})
  end

  def test_run_adds_setup_notice
    stub_dropbox_installed

    @step.run

    assert_equal 1, @step.notices.length
    notice = @step.notices.first
    assert_equal "📦 Dropbox Setup Required", notice[:title]
    assert_includes notice[:message], "Sign in to your Dropbox account"
    assert_includes notice[:message], "~/Dropbox"
  end

  private

  def stub_dropbox_installed
    @fake_system.filesystem["/Applications/Dropbox.app"] = :directory
  end

  def refute_dropbox_installed
    @fake_system.filesystem.delete("/Applications/Dropbox.app")
  end

  def stub_dropbox_configured
    dropbox_folder = File.join(@home, "Dropbox")
    @fake_system.filesystem[dropbox_folder] = :directory
  end

  def refute_dropbox_configured
    dropbox_folder = File.join(@home, "Dropbox")
    @fake_system.filesystem.delete(dropbox_folder)
  end
end
