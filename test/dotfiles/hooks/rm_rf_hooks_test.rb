require "test_helper"
require "json"
require "shellwords"

class RmRfHooksTest < Minitest::Test
  PYTHON_HOOK = File.expand_path("../../../files/home/.claude/hooks/deny-rm-rf.py", __dir__)
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

  def test_python_hook_regex_matches_expected_cases
    assert_pattern_matches("Python", extract_python_pattern, method(:run_python_pattern_test))
  end

  def test_js_hook_regex_matches_expected_cases
    assert_pattern_matches("JS", extract_js_pattern, method(:run_js_pattern_test))
  end

  def test_python_and_js_patterns_are_equivalent
    py_core = extract_python_pattern.sub(/,\s*re\.IGNORECASE\s*$/, "").gsub(/^r"|"$/, "")
    js_core = extract_js_pattern.gsub(%r{^/|/[gi]+$}, "")
    assert_equal py_core, js_core, "Python and JS patterns should be equivalent"
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

  def extract_python_pattern
    extract_pattern(PYTHON_HOOK, /RM_RF_PATTERN\s*=\s*re\.compile\(\s*r"([^"]+)"/)
  end

  def extract_js_pattern
    extract_pattern(JS_HOOK, %r{const RM_RF_PATTERN = (/[^/]+/[a-z]*)})
  end

  def run_python_pattern_test(pattern)
    run_pattern_test("python3 -c", <<~PYTHON)
      import re
      import json
      pattern = re.compile(r"#{pattern}", re.IGNORECASE)
      cases = json.loads('#{test_cases_json}')
      results = {cmd: bool(pattern.search(cmd)) for cmd in cases}
      print(json.dumps(results))
    PYTHON
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
