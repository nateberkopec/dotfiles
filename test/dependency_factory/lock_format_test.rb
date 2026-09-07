require "test_helper"
require_relative "../../tools/ci/dependency_factory"
require_relative "../support/dependency_publication_fixture"

# standard:disable Dotfiles/BanFileSystemClasses
class DependencyLockFormatTest < Minitest::Test
  include DependencyPublicationFixture

  def test_native_format_upgrade_with_exact_specifiers_is_permitted
    output, status = check_format("lockfile_version = 1\n", '["1.0"]')
    assert status.success?, output
  end

  def test_fuzzy_or_wrong_specifiers_are_rejected
    ['["latest"]', '["1.1"]', '"1.0"', "[]"].each do |specifiers|
      output, status = check_format("lockfile_version = 1\n", specifiers)
      refute status.success?, output
      assert_includes output, "Invalid lock specifiers"
    end
  end

  def test_unknown_format_is_rejected
    output, status = check_format("lockfile_version = 2\n", '["1.0"]')
    refute status.success?, output
    assert_includes output, "Unsupported lock format"
  end

  def test_backend_identity_changes_still_require_safety_approval
    output, status = check_format("lockfile_version = 1\n", '["1.0"]', "github:other/tool")
    refute status.success?, output
    assert_includes output, "unsafe changes"
  end

  private

  def check_format(marker, specifiers, backend = "github:test/tool")
    publication_fixture do |fixture|
      lock = File.join(fixture[:agent], "files/home/.config/mise/mise.lock")
      content = "[[tools.tool]]\nversion = \"1.0\"\nbackend = \"github:test/tool\"\n"
      File.write(lock, content)
      fixture_commit(fixture[:agent])
      base = fixture_git(fixture[:agent], "rev-parse", "HEAD")
      File.write(lock, marker + content.sub("github:test/tool", backend) + "specifiers = #{specifiers}\n")
      fixture_commit(fixture[:agent])
      return Open3.capture2e({"BUNDLE_GEMFILE" => File.expand_path("../../Gemfile", __dir__)}, "bundle", "exec", "ruby", File.join(fixture[:source], "tools/ci/check_dependency_update.rb"), base, chdir: fixture[:agent])
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
