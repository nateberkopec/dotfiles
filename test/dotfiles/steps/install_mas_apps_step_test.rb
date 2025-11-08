require "test_helper"

class InstallMasAppsStepTest < Minitest::Test
  def test_complete_returns_true
    step = create_step(Dotfiles::Step::InstallMasAppsStep)
    step.config.mas_apps = {"mas_apps" => {409183694 => "Keynote"}}
    @fake_system.stub_command_output("mas list | grep '^409183694'", "409183694 Keynote (13.1)")

    assert step.complete?
  end

  def test_adds_notice_for_outdated_apps
    step = create_step(Dotfiles::Step::InstallMasAppsStep)
    step.config.mas_apps = {"mas_apps" => {409183694 => "Keynote"}}
    @fake_system.stub_command_output("mas list | grep '^409183694'", "409183694 Keynote (13.1)")
    @fake_system.stub_command_output("mas outdated", "409183694 Keynote (13.1 -> 13.2)")

    step.run

    assert_equal 1, step.notices.size
    assert_includes step.notices.first[:title], "Mac App Store Updates Available"
    assert_includes step.notices.first[:message], "Keynote"
    assert_includes step.notices.first[:message], "mas upgrade"
  end

  def test_no_notice_when_apps_up_to_date
    step = create_step(Dotfiles::Step::InstallMasAppsStep)
    step.config.mas_apps = {"mas_apps" => {409183694 => "Keynote"}}
    @fake_system.stub_command_output("mas list | grep '^409183694'", "409183694 Keynote (13.1)")
    @fake_system.stub_command_output("mas outdated", "")

    step.run

    assert_empty step.notices
  end
end
