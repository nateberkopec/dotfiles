# standard:disable Dotfiles/BanFileSystemClasses -- black-box checker tests require temporary files
require_relative "../test_helper"
require "open3"
require "tmpdir"

class DevEnvMiseTaskFlagsTest < Minitest::Test
  CHECK = File.expand_path("../../files/home/.claude/skills/dev-env-setup/scripts/check-dev-env.fish", __dir__)

  def setup
    skip "fish is required for checker tests" unless system("fish", "--version", out: File::NULL, err: File::NULL)
  end

  def test_allowlisted_families_pass_in_bare_and_lint_forms
    families = %w[complexity dead-code flog flay]

    ["", "lint:"].each do |prefix|
      output = run_checker(families.map { |family| "#{prefix}#{family}" })

      families.each { |family| assert_report output, "PASS", "mise task: lint:#{family}" }
    end
  end

  def test_generic_lint_and_unrelated_tasks_do_not_enable_family_checks
    families = %w[complexity dead-code flog flay]

    %w[lint lint:flog-extra].each do |lint_task|
      output = run_checker([lint_task, "docs"])

      assert_report output, "PASS", "mise task: lint"
      families.each { |family| assert_report output, "FAIL", "mise task: lint:#{family}" }
    end
  end

  private

  def run_checker(tasks)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "source \"https://rubygems.org\"\n")
      File.write(File.join(dir, "mise.toml"), tasks.map { |task| "[tasks.\"#{task}\"]" }.join("\n"))
      return Open3.capture2e({"NO_COLOR" => "1"}, "fish", CHECK, dir).first
    end
  end

  def assert_report(output, status, label)
    assert_includes output, "  #{status}  #{label}"
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
