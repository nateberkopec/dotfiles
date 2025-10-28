require "test_helper"

class InstallApplicationsStepTest < Minitest::Test
  def setup
    super
    @step = create_step(Dotfiles::Step::InstallApplicationsStep)
    stub_applications_config
  end

  def stub_applications_config
    @step.config.packages = {
      "applications" => [
        {
          "name" => "Firefox",
          "brew_cask" => "firefox",
          "path" => "/Applications/Firefox.app"
        },
        {
          "name" => "iTerm2",
          "brew_cask" => "iterm2",
          "path" => "/Applications/iTerm.app"
        },
        {
          "name" => "Docker",
          "brew_cask" => "docker",
          "path" => "/Applications/Docker.app",
          "cli_tap" => "--cli"
        }
      ]
    }
  end

  def test_step_exists
    step = create_step(Dotfiles::Step::InstallApplicationsStep)
    assert_instance_of Dotfiles::Step::InstallApplicationsStep, step
  end

  def test_depends_on_homebrew
    deps = Dotfiles::Step::InstallApplicationsStep.depends_on
    assert_includes deps, Dotfiles::Step::InstallHomebrewStep
  end

  def test_complete_returns_true_when_all_apps_installed
    @fake_system.mkdir_p("/Applications/Firefox.app")
    @fake_system.mkdir_p("/Applications/iTerm.app")
    @fake_system.mkdir_p("/Applications/Docker.app")

    assert @step.complete?
  end

  def test_complete_returns_false_when_any_app_missing
    @fake_system.mkdir_p("/Applications/Firefox.app")
    @fake_system.mkdir_p("/Applications/iTerm.app")

    refute @step.complete?
  end

  def test_complete_returns_false_when_no_apps_installed
    refute @step.complete?
  end

  def test_complete_returns_false_on_exception
    @step.config.packages = nil

    refute @step.complete?
  end

  def test_run_installs_all_applications
    @fake_system.stub_execute_result("brew install --cask  firefox", ["success", 0])
    @fake_system.stub_execute_result("brew install --cask  iterm2", ["success", 0])
    @fake_system.stub_execute_result("brew install --cask  docker --cli", ["success", 0])

    @step.stub :user_has_admin_rights?, true do
      @step.run
    end

    assert @fake_system.received_operation?(:execute, "brew install --cask  firefox", {quiet: true})
    assert @fake_system.received_operation?(:execute, "brew install --cask  iterm2", {quiet: true})
    assert @fake_system.received_operation?(:execute, "brew install --cask  docker --cli", {quiet: true})
  end

  def test_run_skips_already_installed_applications
    @fake_system.mkdir_p("/Applications/Firefox.app")
    @fake_system.mkdir_p("/Applications/iTerm.app")
    @fake_system.stub_execute_result("brew install --cask  docker --cli", ["success", 0])

    @step.stub :user_has_admin_rights?, true do
      @step.run
    end

    refute @fake_system.received_operation?(:execute, "brew install --cask  firefox", {quiet: true})
    refute @fake_system.received_operation?(:execute, "brew install --cask  iterm2", {quiet: true})
    assert @fake_system.received_operation?(:execute, "brew install --cask  docker --cli", {quiet: true})
  end

  def test_install_application_uses_appdir_when_no_admin_rights
    app = {
      "name" => "TestApp",
      "brew_cask" => "testapp",
      "path" => "/Applications/TestApp.app"
    }

    @fake_system.stub_execute_result("brew install --cask --appdir=~/Applications testapp", ["success", 0])

    @step.stub :user_has_admin_rights?, false do
      @step.send(:install_application, app)
    end

    assert @fake_system.received_operation?(:execute, "brew install --cask --appdir=~/Applications testapp", {quiet: true})
  end

  def test_install_application_uses_default_appdir_when_admin
    app = {
      "name" => "TestApp",
      "brew_cask" => "testapp",
      "path" => "/Applications/TestApp.app"
    }

    @fake_system.stub_execute_result("brew install --cask  testapp", ["success", 0])

    @step.stub :user_has_admin_rights?, true do
      @step.send(:install_application, app)
    end

    assert @fake_system.received_operation?(:execute, "brew install --cask  testapp", {quiet: true})
  end

  def test_install_application_handles_cli_tap
    app = {
      "name" => "Docker",
      "brew_cask" => "docker",
      "path" => "/Applications/Docker.app",
      "cli_tap" => "--cli"
    }

    @fake_system.stub_execute_result("brew install --cask  docker --cli", ["success", 0])

    @step.stub :user_has_admin_rights?, true do
      @step.send(:install_application, app)
    end

    assert @fake_system.received_operation?(:execute, "brew install --cask  docker --cli", {quiet: true})
  end

  def test_install_application_without_cli_tap
    app = {
      "name" => "Firefox",
      "brew_cask" => "firefox",
      "path" => "/Applications/Firefox.app"
    }

    @fake_system.stub_execute_result("brew install --cask  firefox", ["success", 0])

    @step.stub :user_has_admin_rights?, true do
      @step.send(:install_application, app)
    end

    assert @fake_system.received_operation?(:execute, "brew install --cask  firefox", {quiet: true})
  end

  def test_install_application_skips_when_already_exists
    app = {
      "name" => "Firefox",
      "brew_cask" => "firefox",
      "path" => "/Applications/Firefox.app"
    }

    @fake_system.mkdir_p("/Applications/Firefox.app")

    @step.stub :user_has_admin_rights?, true do
      @step.send(:install_application, app)
    end

    refute @fake_system.received_operation?(:execute, "brew install --cask  firefox", {quiet: true})
  end
end
