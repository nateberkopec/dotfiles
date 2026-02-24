require "test_helper"

class CheckMiseUpdatesStepTest < Minitest::Test
  def test_complete_returns_true
    step = create_step(Dotfiles::Step::CheckMiseUpdatesStep)
    assert step.complete?
  end

  def test_adds_notice_for_outdated_tools
    step = create_step(Dotfiles::Step::CheckMiseUpdatesStep)
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command("mise --cd /tmp/home cache clear", "")
    @fake_system.stub_command("mise --cd /tmp/home plugins update", "")
    @fake_system.stub_command("mise --cd /tmp/home outdated --bump --no-header", "pi latest 0.54.2 0.54.3\n")

    step.should_run?

    assert_equal 1, step.notices.size
    assert_includes step.notices.first[:title], "Mise Updates Available"
    assert_includes step.notices.first[:message], "1 tool(s)"
    assert_includes step.notices.first[:message], "mise-check-updates"
  end

  def test_no_notice_when_tools_up_to_date
    step = create_step(Dotfiles::Step::CheckMiseUpdatesStep)
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command("mise --cd /tmp/home cache clear", "")
    @fake_system.stub_command("mise --cd /tmp/home plugins update", "")
    @fake_system.stub_command("mise --cd /tmp/home outdated --bump --no-header", "")

    step.should_run?

    assert_empty step.notices
  end

  def test_should_run_returns_false
    step = create_step(Dotfiles::Step::CheckMiseUpdatesStep)
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
    @fake_system.stub_command("mise --cd /tmp/home cache clear", "")
    @fake_system.stub_command("mise --cd /tmp/home plugins update", "")
    @fake_system.stub_command("mise --cd /tmp/home outdated --bump --no-header", "")

    refute step.should_run?
  end

  def test_should_not_run_when_offline
    step = create_step(Dotfiles::Step::CheckMiseUpdatesStep)

    with_env("MISE_OFFLINE" => "1") do
      refute step.should_run?
    end
  end

  def test_should_not_run_when_mise_missing
    step = create_step(Dotfiles::Step::CheckMiseUpdatesStep)
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 1)

    refute step.should_run?
  end
end
