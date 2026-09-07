require "test_helper"
require "json"
require "yaml"
require "open3"

# standard:disable Dotfiles/BanFileSystemClasses
class DependencyFactoryAccountingTest < Minitest::Test
  def test_failed_or_incomplete_runs_are_accounted_exactly_once
    source = File.expand_path("../../.github/workflows/dependency-updater.md", __dir__)
    jobs = YAML.safe_load(File.read(source).split(/^---$/)[1], aliases: true).fetch("jobs")
    expressions = [jobs.fetch("conclusion").fetch("if"), jobs.fetch("failure_accounting").fetch("if")]
    script = <<~JS
      const expressions = JSON.parse(process.argv[1]);
      for (const agent of ['success', 'failure', 'cancelled', 'skipped']) {
        for (const validation of ['success', 'failure', 'cancelled', 'skipped']) {
          for (const validated of ['true', 'false', '']) {
            const needs = {agent: {result: agent}, validation: {result: validation, outputs: {validated}}};
            const results = expressions.map(expression => new Function('needs', 'always', 'return ' + expression)(needs, () => true));
            if (results.filter(Boolean).length !== 1) throw new Error(JSON.stringify(needs));
          }
        }
      }
      console.log('All 48 success/failure/cancel/skip/marker combinations account exactly once');
    JS
    output, status = Open3.capture2e("node", "-e", script, JSON.generate(expressions))
    assert status.success?, output
    assert_includes output, "All 48"
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
