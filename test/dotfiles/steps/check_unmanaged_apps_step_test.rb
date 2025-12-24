require "test_helper"

class CheckUnmanagedAppsStepTest < Minitest::Test
  def test_complete_returns_true
    step = create_step(Dotfiles::Step::CheckUnmanagedAppsStep)
    assert step.complete?
  end

  def test_adds_notice_for_missing_app
    step = create_step(Dotfiles::Step::CheckUnmanagedAppsStep)
    step.config.unmanaged_apps = ["/Applications/Screen Studio.app"]

    step.run

    assert_equal 1, step.notices.size
    assert_includes step.notices.first[:message], "Screen Studio"
  end

  def test_no_notice_for_installed_app
    step = create_step(Dotfiles::Step::CheckUnmanagedAppsStep)
    step.config.unmanaged_apps = ["/Applications/Screen Studio.app"]
    @fake_system.mkdir_p("/Applications/Screen Studio.app")

    step.run

    assert_empty step.notices
  end

  def test_respects_skipped_apps_file
    step = create_step(Dotfiles::Step::CheckUnmanagedAppsStep)
    step.config.unmanaged_apps = ["/Applications/Monologue.app", "/Applications/Effortless.app"]
    @fake_system.stub_file_content("#{@dotfiles_dir}/.skipped-apps", "Monologue\n")

    step.run

    assert_equal 1, step.notices.size
    assert_includes step.notices.first[:message], "Effortless"
    refute_includes step.notices.first[:message], "Monologue"
  end

  def test_handles_empty_skipped_apps_file
    step = create_step(Dotfiles::Step::CheckUnmanagedAppsStep)
    step.config.unmanaged_apps = ["/Applications/Screen Studio.app"]
    @fake_system.stub_file_content("#{@dotfiles_dir}/.skipped-apps", "\n\n")

    step.run

    assert_equal 1, step.notices.size
  end

  def test_handles_no_skipped_apps_file
    step = create_step(Dotfiles::Step::CheckUnmanagedAppsStep)
    step.config.unmanaged_apps = ["/Applications/Screen Studio.app"]

    step.run

    assert_equal 1, step.notices.size
  end

  def test_handles_multiple_missing_apps
    step = create_step(Dotfiles::Step::CheckUnmanagedAppsStep)
    step.config.unmanaged_apps = [
      "/Applications/Screen Studio.app",
      "/Applications/Monologue.app",
      "/Applications/Effortless.app"
    ]

    step.run

    assert_equal 1, step.notices.size
    assert_includes step.notices.first[:message], "Screen Studio"
    assert_includes step.notices.first[:message], "Monologue"
    assert_includes step.notices.first[:message], "Effortless"
  end

  def test_filters_out_homebrew_managed_apps
    step = create_step(Dotfiles::Step::CheckUnmanagedAppsStep)
    step.config.unmanaged_apps = ["/Applications/Screen Studio.app", "/Applications/Arc.app"]
    step.config.packages = {
      "applications" => [
        {"name" => "Arc", "path" => "/Applications/Arc.app", "brew_cask" => "arc"}
      ]
    }

    step.run

    assert_equal 1, step.notices.size
    assert_includes step.notices.first[:message], "Screen Studio"
    refute_includes step.notices.first[:message], "Arc"
  end
end
