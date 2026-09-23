require "test_helper"
require "json"
require "open3"
require "tmpdir"
require "fileutils"
require_relative "../../tools/ci/dependency_factory"

# Real git state and queued output exercise validation and the published artifact together.
# standard:disable Dotfiles/BanFileSystemClasses
class DependencyFactoryPublishedReportTest < Minitest::Test
  def test_creation_and_revision_publish_working_links_without_reactivating_mentions
    %w[create_pull_request update_pull_request].each do |type|
      Dir.mktmpdir do |root|
        setup_checkout(root)
        write_inputs(root, type)
        script = File.expand_path("../../tools/ci/check_dependency_output.rb", __dir__)
        gemfile = File.expand_path("../../Gemfile", __dir__)
        output, status = Open3.capture2e({"BUNDLE_GEMFILE" => gemfile}, "bundle", "exec", "ruby", script, "#{root}/agent", chdir: root)
        assert status.success?, output
        published = JSON.parse(File.read("#{root}/agent_output.json")).fetch("items").first.fetch("body")
        assert_includes published, "https://www.npmjs.com/package/%40narumitw/pi-btw/v/0.60.0"
        refute_includes published, "/package/``@"
        assert_includes published, "(``@P4P3R-HAK``)"
        assert_equal published, File.read("#{root}/agent/pr-body.md")
      end
    end
  end

  private

  def setup_checkout(root)
    git(root, "init", "-qb", "dependency-update-test")
    File.write("#{root}/.git/info/exclude", "/agent/\n/agent_output.json\n*.bundle\n")
    DependencyFactory::Manifests::PATHS.each do |path|
      FileUtils.mkdir_p(File.dirname("#{root}/#{path}"))
      File.write("#{root}/#{path}", "")
    end
    File.write("#{root}/config/dependency-updater.yml", "{}\n")
    git(root, "add", ".")
    git(root, "commit", "--no-gpg-sign", "-qm", "Fixture")
    git(root, "bundle", "create", "#{root}/aw-dependency-update-test.bundle", "dependency-update-test")
  end

  def write_inputs(root, type)
    Dir.mkdir("#{root}/agent")
    head = git(root, "rev-parse", "HEAD").strip
    context = {"base" => head, "head" => head, "number" => ((type == "update_pull_request") ? 2 : nil)}
    write_json(root, "agent/pr-context.json", context)
    item = {"type" => type, "body" => body, "branch" => "dependency-update-test"}
    write_json(root, "agent_output.json", {"items" => [item], "errors" => []})
    candidate = {"name" => "pi:@narumitw/pi-btw", "current" => "0.56.2", "eligible" => "0.60.0", "latest" => "0.60.0", "published" => {"0.60.0" => "2026-09-01T00:00:00Z"}}
    write_json(root, "agent/dependency-candidates.json", {"generated_at" => "2026-09-20T00:00:00Z", "minimum_release_age_days" => 3, "candidates" => [candidate]})
    note = {"version" => "0.60.0", "url" => "https://www.npmjs.com/package/@narumitw/pi-btw/v/0.60.0", "text" => "The vulnerability reported by (@P4P3R-HAK) is fixed."}
    write_json(root, "agent/release-notes.json", {"packages" => {candidate["name"] => [note]}})
  end

  def body
    <<~MARKDOWN
      ## Release notes
      No upgrades in this batch.
      ## Updates
      | Tool | Old | New |
      | --- | --- | --- |
      ## Skipped candidates
      | Tool | Candidate | Reason |
      | --- | --- | --- |
      | pi:``@narumitw/pi-btw`` | [0.60.0](https://www.npmjs.com/package/``@narumitw/pi-btw``/v/0.60.0) | Manual review needed. |
      ## Attention
      - Security: `pi:@narumitw/pi-btw 0.60.0`: [Fix.](https://www.npmjs.com/package/``@narumitw/pi-btw``/v/0.60.0) "The vulnerability reported by (``@P4P3R-HAK``) is fixed."
      Validation: tests passed.
    MARKDOWN
  end

  def write_json(root, path, value)
    File.write("#{root}/#{path}", JSON.generate(value))
  end

  def git(root, *args)
    output, status = Open3.capture2e("git", "-C", root, "-c", "core.hooksPath=/dev/null", "-c", "user.name=Test", "-c", "user.email=test@example.test", *args)
    assert status.success?, output
    output
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
