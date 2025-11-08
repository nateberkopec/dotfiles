require "test_helper"

class CheckNonHomebrewAppsStepTest < Minitest::Test
  def test_complete_returns_true
    step = create_step(Dotfiles::Step::CheckNonHomebrewAppsStep)
    assert step.complete?
  end

  def test_adds_notice_for_missing_app
    step = create_step(Dotfiles::Step::CheckNonHomebrewAppsStep)
    step.config.non_homebrew_apps = ["/Applications/Obsidian.app"]

    step.run

    assert_equal 1, step.notices.size
    assert_includes step.notices.first[:title], "Obsidian"
  end

  def test_no_notice_for_installed_app
    step = create_step(Dotfiles::Step::CheckNonHomebrewAppsStep)
    step.config.non_homebrew_apps = ["/Applications/Obsidian.app"]
    @fake_system.mkdir_p("/Applications/Obsidian.app")

    step.run

    assert_empty step.notices
  end

  def test_respects_skipped_apps_file
    step = create_step(Dotfiles::Step::CheckNonHomebrewAppsStep)
    step.config.non_homebrew_apps = ["/Applications/Obsidian.app", "/Applications/Slack.app"]
    @fake_system.stub_file_content("#{@dotfiles_dir}/.skipped-apps", "Obsidian\n")

    step.run

    assert_equal 1, step.notices.size
    assert_includes step.notices.first[:title], "Slack"
    refute step.notices.any? { |n| n[:title].include?("Obsidian") }
  end

  def test_handles_empty_skipped_apps_file
    step = create_step(Dotfiles::Step::CheckNonHomebrewAppsStep)
    step.config.non_homebrew_apps = ["/Applications/Obsidian.app"]
    @fake_system.stub_file_content("#{@dotfiles_dir}/.skipped-apps", "\n\n")

    step.run

    assert_equal 1, step.notices.size
  end

  def test_handles_no_skipped_apps_file
    step = create_step(Dotfiles::Step::CheckNonHomebrewAppsStep)
    step.config.non_homebrew_apps = ["/Applications/Obsidian.app"]

    step.run

    assert_equal 1, step.notices.size
  end

  def test_handles_multiple_missing_apps
    step = create_step(Dotfiles::Step::CheckNonHomebrewAppsStep)
    step.config.non_homebrew_apps = [
      "/Applications/Obsidian.app",
      "/Applications/Slack.app",
      "/Applications/Discord.app"
    ]

    step.run

    assert_equal 3, step.notices.size
  end

  def test_filters_out_homebrew_managed_apps
    step = create_step(Dotfiles::Step::CheckNonHomebrewAppsStep)
    step.config.non_homebrew_apps = ["/Applications/Obsidian.app", "/Applications/Arc.app"]
    step.config.packages = {
      "applications" => [
        {"name" => "Arc", "path" => "/Applications/Arc.app", "brew_cask" => "arc"}
      ]
    }

    step.run

    assert_equal 1, step.notices.size
    assert_includes step.notices.first[:title], "Obsidian"
    refute step.notices.any? { |n| n[:title].include?("Arc") }
  end
end
