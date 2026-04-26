require "test_helper"
require "stringio"

class OutputFormatterTest < Minitest::Test
  def test_display_prints_table_and_success_without_exiting
    calls, csv = formatter_calls_for(results(failed_steps: []))

    assert_includes csv, "Step,Status,Ran?"
    assert_table_call(calls)
    assert_system_call_includes(calls, "#50fa7b")
    refute_exit_call(calls)
  end

  def test_display_exits_when_failed_steps_present
    calls, = formatter_calls_for(results(failed_steps: ["SomeStep"]))

    assert_system_call_includes(calls, "❌ Installation Failed!")
    assert_exit_call(calls, 1)
  end

  def test_display_uses_doctor_status_messages_for_doctor_context
    success_calls, = formatter_calls_for(results(failed_steps: []), context: :doctor)
    failure_calls, = formatter_calls_for(results(failed_steps: ["SomeStep"]), context: :doctor)

    assert_system_call_includes(success_calls, "🩺 Dotfiles Doctor Passed!")
    assert_system_call_includes(failure_calls, "🩺 Dotfiles Doctor Found Drift!")
  end

  def test_display_formats_errors_warnings_and_notices
    calls, = formatter_calls_for(
      results(
        errors: [
          {step: "StepA", message: "bad thing"},
          {step: "StepA", message: "another bad thing"}
        ],
        warnings: [{title: "Warn", message: "careful"}],
        notices: [{title: "Note", message: "heads up"}]
      )
    )

    assert_system_call_includes(calls, "#ff5555", "❌ StepA")
    assert_system_call_includes(calls, "#ffaa00", "Warn", "careful")
    assert_system_call_includes(calls, "#00aaff", "Note", "heads up")
  end

  private

  def assert_table_call(calls)
    assert calls.any? { |call| table_call?(call) }
  end

  def table_call?(call)
    kind, cmd, mode = call
    kind == :popen && cmd[0..1] == ["gum", "table"] && mode == "w"
  end

  def assert_system_call_includes(calls, *expected)
    assert calls.any? { |call| system_call_includes?(call, expected) }
  end

  def system_call_includes?(call, expected)
    kind, args = call
    kind == :system && expected.all? { |arg| args.include?(arg) }
  end

  def assert_exit_call(calls, code)
    assert calls.any? { |call| exit_call?(call, code) }
  end

  def refute_exit_call(calls)
    refute calls.any? { |call| call.first == :exit }
  end

  def exit_call?(call, code)
    kind, actual_code = call
    kind == :exit && actual_code == code
  end

  def formatter_calls_for(results_hash, context: :run)
    calls = []
    csv = +""

    popen_call = lambda do |cmd, mode, &block|
      calls << [:popen, cmd, mode]
      io = StringIO.new
      block.call(io)
      csv << io.string
    end

    system_call = lambda do |*args|
      calls << [:system, args]
      true
    end

    exit_call = lambda do |code|
      calls << [:exit, code]
      nil
    end

    Dotfiles::OutputFormatter.new(results_hash, context: context, popen_call: popen_call, system_call: system_call, exit_call: exit_call).display
    [calls, csv]
  end

  def results(
    table_data: [["Step1", "OK", "Y"]],
    errors: [],
    warnings: [],
    notices: [],
    failed_steps: []
  )
    {
      table_data: table_data,
      errors: errors,
      warnings: warnings,
      notices: notices,
      failed_steps: failed_steps
    }
  end
end
