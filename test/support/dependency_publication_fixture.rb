require "tmpdir"
require "fileutils"
require "open3"
require "json"

# standard:disable Dotfiles/BanFileSystemClasses
module DependencyPublicationFixture
  private

  def publication_fixture
    Dir.mktmpdir do |root|
      source, agent, evidence, directory = %w[source checkout evidence artifacts/agent].map { |name| File.join(root, name) }
      [source, evidence, directory].each { |path| FileUtils.mkdir_p(path) }
      project = File.expand_path("../..", __dir__)
      FileUtils.cp_r(File.join(project, "tools"), source)
      DependencyFactory::DEPENDENCY_PATHS.each do |path|
        FileUtils.mkdir_p(File.dirname(File.join(source, path)))
        File.write(File.join(source, path), "")
      end
      %w[Gemfile Gemfile.lock].each { |path| FileUtils.cp(File.join(project, path), source) }
      File.write(File.join(source, ".mise.toml"), "[tools]\nhk = \"1.0\"\n")
      File.write(File.join(source, "config/dependency-updater.yml"), "snoozes: {}\n")
      fixture_git(source, "init", "-qb", "dependency-update-test")
      fixture_commit(source)
      base = fixture_git(source, "rev-parse", "HEAD")
      fixture_git(root, "clone", "-q", source, agent)
      documents = {"pr-context" => {"base" => base}, "dependency-candidates" => {"candidates" => [], "generated_at" => "2026-09-06T18:11:29Z", "minimum_release_age_days" => 3}, "release-notes" => {"packages" => {}}}
      fixture = {root: root, source: source, agent: agent, evidence: evidence, directory: directory, base: base}
      documents.each { |name, data| write_evidence(fixture, name, data) }
      yield fixture
    end
  end

  def resume_publication(fixture, head)
    write_evidence(fixture, "pr-context", {"base" => fixture[:base], "head" => head, "number" => 2})
    Dir.mkdir(File.join(fixture[:root], "bin"))
    stub = File.join(fixture[:root], "bin/gh")
    File.write(stub, "#!/bin/sh\nprintf '#{head}'\n")
    File.chmod(0o755, stub)
  end

  def write_evidence(fixture, name, data)
    fixture.values_at(:directory, :evidence).each { |path| File.write(File.join(path, "#{name}.json"), JSON.generate(data)) }
  end

  def fixture_git(root, *arguments)
    out, err, status = Open3.capture3("git", "-C", root, "-c", "core.hooksPath=/dev/null", "-c", "user.name=Test", "-c", "user.email=test@example.test", *arguments)
    raise err unless status.success?
    out.strip
  end

  def fixture_commit(root)
    fixture_git(root, "add", ".")
    fixture_git(root, "commit", "--no-gpg-sign", "-qm", "Fixture")
  end

  def publication_bundle(fixture, refs = ["dependency-update-test"])
    path = File.join(fixture[:directory], "../aw-dependency-update-test.bundle")
    fixture_git(fixture[:agent], "bundle", "create", path, *refs)
    path
  end

  def validate_publication(fixture, items = [{"type" => "noop"}])
    File.write(File.join(fixture[:directory], "../agent_output.json"), JSON.generate("items" => items))
    script = File.join(fixture[:source], "tools/ci/validate_dependency_publication.rb")
    bundle_path = Bundler.settings[:path]
    Open3.capture2e({"PATH" => "#{fixture[:root]}/bin:#{ENV["PATH"]}", "GITHUB_REPOSITORY" => "test/test", "BUNDLE_GEMFILE" => File.join(fixture[:source], "Gemfile"), "BUNDLE_PATH" => bundle_path && File.expand_path(bundle_path, Bundler.root)}, "bundle", "exec", "ruby", script, fixture[:directory], fixture[:evidence], File.join(fixture[:root], "publication.sha256"), chdir: fixture[:source])
  end

  def publication_item
    {"type" => "create_pull_request", "branch" => "dependency-update-test", "body" => "```json dependency-decisions\n{\"outcome\":\"researched\",\"decisions\":[]}\n```"}
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
