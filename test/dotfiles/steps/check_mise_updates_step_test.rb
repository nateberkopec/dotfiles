require "test_helper"

class CheckMiseUpdatesStepTest < Minitest::Test
  def test_complete_returns_true
    step = create_step(Dotfiles::Step::CheckMiseUpdatesStep)
    assert step.complete?
  end

  def test_adds_notice_for_actionable_outdated_tools
    step = create_step(Dotfiles::Step::CheckMiseUpdatesStep)
    stub_mise_available
    stub_mise_update_check(<<~JSON)
      {"pi":{"requested":"0.54","current":"0.54.2","latest":"0.54.3"}}
    JSON

    step.should_run?

    assert_notice_count(step, 1)
    assert_notice_title_includes(step, "Mise Updates Available")
    assert_notice_message_includes(step, "1 tool(s)")
    assert_notice_message_includes(step, "mise-check-updates")
  end

  def test_no_notice_when_tools_up_to_date
    step = create_step(Dotfiles::Step::CheckMiseUpdatesStep)
    stub_mise_available
    stub_mise_update_check("{}")

    step.should_run?

    assert_empty step.notices
  end

  def test_should_run_returns_false
    step = create_step(Dotfiles::Step::CheckMiseUpdatesStep)
    stub_mise_available
    stub_mise_update_check("{}")

    refute step.should_run?
  end

  def test_should_not_run_when_offline
    step = create_step(Dotfiles::Step::CheckMiseUpdatesStep)

    with_env("MISE_OFFLINE" => "1") do
      refute step.should_run?
    end
  end

  def test_ignores_alias_noise_from_latest_and_lts
    step = create_step(Dotfiles::Step::CheckMiseUpdatesStep)
    stub_mise_available
    stub_mise_update_check(<<~JSON)
      {
        "pkl":{"requested":"latest","current":"latest","latest":"0.31.1","bump":null},
        "node":{"requested":"lts","current":"24.14.1","latest":"25.9.0","bump":null}
      }
    JSON

    step.should_run?

    assert_empty step.notices
  end

  def test_should_not_run_when_mise_missing
    step = create_step(Dotfiles::Step::CheckMiseUpdatesStep)
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 1)

    refute step.should_run?
  end

  private

  def stub_mise_available
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "", exit_status: 0)
  end

  def stub_mise_update_check(output)
    @fake_system.stub_command("mise --cd /tmp/home plugins update", "")
    @fake_system.stub_command("mise --cd /tmp/home outdated --json 2>/dev/null", output)
  end

  def assert_notice_count(step, count)
    assert_equal count, step.notices.size
  end

  def assert_notice_title_includes(step, text)
    assert_includes step.notices.first[:title], text
  end

  def assert_notice_message_includes(step, text)
    assert_includes step.notices.first[:message], text
  end
end
