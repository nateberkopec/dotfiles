require "test_helper"
require "stringio"

class OutputFormatterTest < Minitest::Test
  def test_display_prints_table_and_success_without_exiting
    calls, csv = formatter_calls_for(results(failed_steps: []))

    assert_includes csv, "Step,Status,Ran?"
    assert calls.any? { |(kind, cmd, mode)| kind == :popen && cmd[0..1] == ["gum", "table"] && mode == "w" }
    assert calls.any? { |(kind, args)| kind == :system && args.include?("#50fa7b") }
    refute calls.any? { |(kind, _)| kind == :exit }
  end

  def test_display_exits_when_failed_steps_present
    calls, = formatter_calls_for(results(failed_steps: ["SomeStep"]))

    assert calls.any? { |(kind, args)| kind == :system && args.include?("❌ Installation Failed!") }
    assert calls.any? { |(kind, code)| kind == :exit && code == 1 }
  end

  def test_display_formats_errors_warnings_and_notices
    calls, _, output = formatter_calls_for(
      results(
        errors: [
          {step: "StepA", message: "bad thing"},
          {step: "StepA", message: "another bad thing"}
        ],
        warnings: [{title: "Warn", message: "careful"}],
        notices: [{title: "Note", message: "heads up"}]
      )
    )

    assert_includes output, "❌ StepA\nbad thing\n\nanother bad thing"
    assert calls.any? { |(kind, args)| kind == :system && args.include?("#ffaa00") && args.include?("Warn") && args.include?("careful") }
    assert calls.any? { |(kind, args)| kind == :system && args.include?("#00aaff") && args.include?("Note") && args.include?("heads up") }
  end

  def test_errors_preserve_long_commands_and_multiline_output_without_gum_wrapping
    message = "Failed to link plugin\nunknown option: /#{"long-path/" * 20}\nCommand: herdr plugin link"
    calls, _, output = formatter_calls_for(results(errors: [{step: "Link Herdr Plugins", message: message}]))

    assert_includes output, message
    refute calls.any? { |kind, args| kind == :system && args.include?(message) }
  end

  private

  def formatter_calls_for(results_hash)
    calls = []
    csv = +""
    output = StringIO.new

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

    Dotfiles::OutputFormatter.new(results_hash, popen_call: popen_call, system_call: system_call, exit_call: exit_call, output: output).display
    [calls, csv, output.string]
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
