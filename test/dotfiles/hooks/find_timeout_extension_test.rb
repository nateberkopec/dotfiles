require "test_helper"
require "json"
require "shellwords"

class FindTimeoutExtensionTest < Minitest::Test
  EXTENSION = File.expand_path("../../../files/home/.pi/agent/extensions/find_timeout.ts", __dir__)

  SHOULD_MATCH = [
    "find . -type f",
    "sudo find / -name foo",
    "command find . -maxdepth 1",
    "echo hi && find . -name '*.rb'",
    "(find . -type d)",
    "echo one\nfind . -type f"
  ].freeze

  SHOULD_NOT_MATCH = [
    "fd --find foo",
    "grep find README.md",
    "echo finder",
    "python -c \"print('find')\""
  ].freeze

  def test_find_command_pattern_matches_expected_cases
    pattern = extract_pattern
    results = run_pattern_test(pattern)

    SHOULD_MATCH.each { |cmd| assert results[cmd], "pattern should match: #{cmd.inspect}" }
    SHOULD_NOT_MATCH.each { |cmd| refute results[cmd], "pattern should NOT match: #{cmd.inspect}" }
  end

  private

  def extract_pattern
    content = Dotfiles::SystemAdapter.new.read_file(EXTENSION)
    match = content.match(%r{const FIND_COMMAND_PATTERN = (/[^\n]+/[a-z]*);})
    assert match, "Could not extract FIND_COMMAND_PATTERN"
    match[1]
  end

  def run_pattern_test(pattern)
    script = <<~JS
      const pattern = #{pattern};
      const cases = #{test_cases_json};
      const results = {};
      for (const command of cases) {
        pattern.lastIndex = 0;
        results[command] = pattern.test(command);
      }
      console.log(JSON.stringify(results));
    JS

    JSON.parse(`node -e #{script.shellescape}`)
  end

  def test_cases_json
    (SHOULD_MATCH + SHOULD_NOT_MATCH).to_json
  end
end
