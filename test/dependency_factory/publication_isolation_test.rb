require "test_helper"
require_relative "../../tools/ci/dependency_factory"
require_relative "../support/dependency_publication_fixture"

# standard:disable Dotfiles/BanFileSystemClasses
class DependencyPublicationIsolationTest < Minitest::Test
  include DependencyPublicationFixture

  def test_exact_queued_bundle_is_validated_not_an_agent_checkout
    publication_fixture do |fixture|
      publication_bundle(fixture)
      File.write(File.join(fixture[:agent], "Gemfile"), 'abort "Candidate Gemfile executed"')
      FileUtils.mkdir_p(File.join(fixture[:directory], "checks"))
      File.write(File.join(fixture[:directory], "checks/check_dependency_report.rb"), 'abort "Agent checker executed"')
      output, status = validate_publication(fixture, [publication_item])
      assert status.success?, output
    end
  end

  def test_agent_git_hooks_and_configuration_cannot_execute_in_validation
    publication_fixture do |fixture|
      marker = File.join(fixture[:root], "executed")
      hook = File.join(fixture[:root], "fsmonitor")
      File.write(hook, "#!/bin/sh\ntouch #{marker}\nprintf 'token\\0'\n")
      File.chmod(0o755, hook)
      fixture_git(fixture[:agent], "config", "core.fsmonitor", hook)
      fixture_git(fixture[:agent], "status", "--porcelain")
      assert File.exist?(marker), "Poison must execute without isolation"
      File.unlink(marker)
      publication_bundle(fixture)
      output, status = validate_publication(fixture, [publication_item])
      assert status.success?, output
      refute File.exist?(marker)
    end
  end

  def test_bundle_must_descend_from_the_trusted_base
    publication_fixture do |fixture|
      fixture_git(fixture[:agent], "checkout", "--orphan", "unrelated")
      File.write(File.join(fixture[:agent], ".mise.toml"), "[tools]\nhk = \"1.1\"\n")
      fixture_commit(fixture[:agent])
      path = publication_bundle(fixture, ["unrelated"])
      File.rename(path, File.join(fixture[:directory], "../aw-unrelated.bundle"))
      output, status = validate_publication(fixture, [publication_item.merge("branch" => "unrelated")])
      refute status.success?
      assert_includes output, "merge-base"
    end
  end

  def test_publication_manifest_detects_payload_replacement
    publication_fixture do |fixture|
      output, status = validate_publication(fixture)
      assert status.success?, output
      manifest = File.join(fixture[:root], "publication.sha256")
      _, status = Open3.capture2e("shasum", "-a", "256", "-c", manifest)
      assert status.success?
      File.write(File.join(fixture[:directory], "../agent_output.json"), '{"items":[]}')
      _, status = Open3.capture2e("shasum", "-a", "256", "-c", manifest)
      refute status.success?
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
