require "test_helper"
require "json"
require "shellwords"

class RmRfHooksTest < Minitest::Test
  JQ_HOOK = File.expand_path("../../../files/home/.claude/hooks/deny-rm-rf.py", __dir__)
  JS_HOOK = File.expand_path("../../../files/home/.config/opencode/plugin/deny-rm-rf.js", __dir__)

  SHOULD_MATCH = [
    "rm -rf /foo",
    "rm -fr /foo",
    "rm -rfi /foo",
    "rm -rfv /foo",
    "rm -rif /foo",
    "rm -vrf /foo",
    "rm -Rf /foo",
    "rm -RF /foo",
    "sudo rm -rf /foo",
    "command rm -rf /foo",
    "echo hi; rm -rf /foo",
    "echo hi && rm -rf /foo",
    "rm  -rf /foo"
  ].freeze

  SHOULD_NOT_MATCH = [
    "rm -r /foo",
    "rm -f /foo",
    "rm -rf",
    "inform -rf /foo",
    "rm-rf /foo",
    "rm -rf/foo"
  ].freeze

  def test_jq_hook_regex_matches_expected_cases
    assert_pattern_matches("JQ", extract_jq_pattern, method(:run_jq_pattern_test))
  end

  def test_js_hook_regex_matches_expected_cases
    assert_pattern_matches("JS", extract_js_pattern, method(:run_js_pattern_test))
  end

  def test_jq_and_js_patterns_are_equivalent
    jq_core = extract_jq_pattern
    js_core = extract_js_pattern.gsub(%r{^/|/[gi]+$}, "")
    assert_equal jq_core, js_core, "JQ and JS patterns should be equivalent"
  end

  private

  def assert_pattern_matches(lang, pattern, runner)
    results = runner.call(pattern)
    SHOULD_MATCH.each { |cmd| assert results[cmd], "#{lang} pattern should match: #{cmd.inspect}" }
    SHOULD_NOT_MATCH.each { |cmd| refute results[cmd], "#{lang} pattern should NOT match: #{cmd.inspect}" }
  end

  def extract_pattern(file, regex)
    content = File.read(file)
    match = content.match(regex)
    assert match, "Could not extract pattern from #{File.basename(file)}"
    match[1]
  end

  def extract_jq_pattern
    extract_pattern(JQ_HOOK, /def\s+RM_RF_PATTERN:\s*"([^"]+)"/)
  end

  def extract_js_pattern
    extract_pattern(JS_HOOK, %r{const RM_RF_PATTERN = (/[^/]+/[a-z]*)})
  end

  def run_jq_pattern_test(pattern)
    run_pattern_test("jq -n", <<~JQ)
      def rm_rf_pattern: #{pattern.to_json};
      (#{test_cases_json}) as $cases
      | reduce $cases[] as $cmd ({}; . + { ($cmd): ($cmd | test(rm_rf_pattern; "i")) })
    JQ
  end

  def run_js_pattern_test(pattern)
    run_pattern_test("node -e", <<~JS)
      const pattern = #{pattern};
      const cases = JSON.parse('#{test_cases_json}');
      const results = {};
      cases.forEach(cmd => { pattern.lastIndex = 0; results[cmd] = pattern.test(cmd); });
      console.log(JSON.stringify(results));
    JS
  end

  def run_pattern_test(cmd, script)
    JSON.parse(`#{cmd} #{script.shellescape}`)
  end

  def test_cases_json
    (SHOULD_MATCH + SHOULD_NOT_MATCH).to_json
  end
end
