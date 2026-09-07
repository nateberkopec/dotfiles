require "test_helper"
require_relative "../../tools/ci/dependency_factory"
require_relative "../support/dependency_publication_fixture"

# standard:disable Dotfiles/BanFileSystemClasses
class ReproduceMiseLockTest < Minitest::Test
  include DependencyPublicationFixture

  def test_independent_generation_preserves_the_proposal_and_certifies_its_commit
    native_fixture do |fixture, expected|
      output, status = reproduce(fixture)
      assert status.success?, output
      assert_equal expected, File.binread(lock_path(fixture))
      assert_equal "#{fixture_git(fixture[:agent], "rev-parse", "HEAD")}\n", File.read(File.join(fixture[:root], "native/macos-arm64.sha"))
    end
  end

  def test_opposite_platform_option_variant_is_merged_only_as_scratch_input
    native_fixture do |fixture, native|
      other = {"version" => "1.0", "backend" => "github:test/tool", "specifiers" => ["1.0"], "options" => {"asset_pattern" => "linux"}, "platforms.linux-x64" => {"checksum" => "linux-checksum"}}
      data = TomlRB.parse(native)
      data.fetch("tools").fetch("tool") << other
      expected = TomlRB.dump(data)
      File.write(lock_path(fixture), expected)
      fixture_commit(fixture[:agent])
      File.write(File.join(fixture[:root], "merged.lock"), expected)
      script = "lock=\"$2/files/home/.config/mise/mise.lock\"\nif grep -q '\\[\\[tools' \"$lock\"; then cmp '#{fixture[:root]}/merged.lock' \"$lock\"; else cp '#{fixture[:root]}/canonical.lock' \"$lock\"; fi\n"
      File.write(File.join(fixture[:source], "tools/ci/lock_native_platform.sh"), script)
      output, status = reproduce(fixture)
      assert status.success?, output
      assert_equal expected, File.read(lock_path(fixture))
    end
  end

  def test_legacy_format_is_reproduced_without_accepting_existing_records
    native_fixture do |fixture, native|
      legacy = native.sub("lockfile_version = 1\n\n", "").sub("specifiers = [\"1.0\"]\n", "")
      File.write(lock_path(fixture), legacy)
      fixture_commit(fixture[:agent])
      File.write(File.join(fixture[:root], "canonical.lock"), legacy)
      script = "lock=\"$2/files/home/.config/mise/mise.lock\"\nif ! grep -q '\\[\\[tools' \"$lock\"; then test ! -s \"$lock\" || exit 1; fi\ncp '#{fixture[:root]}/canonical.lock' \"$lock\"\n"
      File.write(File.join(fixture[:source], "tools/ci/lock_native_platform.sh"), script)
      output, status = reproduce(fixture)
      assert status.success?, output
      assert_equal legacy, File.read(lock_path(fixture))
    end
  end

  def test_both_platforms_reproduce_one_record_order
    native_fixture do |fixture, _|
      records = %w[linux-x64 macos-arm64].map do |platform|
        {"version" => "1.0", "backend" => "github:test/tool", "specifiers" => ["1.0"], "options" => {"asset_pattern" => platform}, "platforms.#{platform}" => {"checksum" => platform}}
      end
      expected = TomlRB.dump({"lockfile_version" => 1, "tools" => {"tool" => records}})
      File.write(lock_path(fixture), expected)
      fixture_commit(fixture[:agent])
      File.write(File.join(fixture[:root], "merged.lock"), expected)
      %w[linux-x64 macos-arm64].zip(records).each do |platform, record|
        File.write(File.join(fixture[:root], "#{platform}.lock"), TomlRB.dump({"lockfile_version" => 1, "tools" => {"tool" => [record]}}))
      end
      script = "lock=\"$2/files/home/.config/mise/mise.lock\"\nif grep -q '\\[\\[tools' \"$lock\"; then cmp '#{fixture[:root]}/merged.lock' \"$lock\"; else cp \"#{fixture[:root]}/$1.lock\" \"$lock\"; fi\n"
      File.write(File.join(fixture[:source], "tools/ci/lock_native_platform.sh"), script)
      %w[linux-x64 macos-arm64].each do |platform|
        output, status = reproduce(fixture, platform)
        assert status.success?, output
        assert_equal "#{fixture_git(fixture[:agent], "rev-parse", "HEAD")}\n", File.read(File.join(fixture[:root], "native/#{platform}.sha"))
      end
      assert_equal expected, File.read(lock_path(fixture))
    end
  end

  def test_authentic_dirty_worktree_cannot_certify_a_forged_commit
    native_fixture do |fixture, authentic|
      File.write(lock_path(fixture), authentic.sub("authentic", "forged"))
      fixture_commit(fixture[:agent])
      File.write(lock_path(fixture), authentic)
      output, status = reproduce(fixture)
      refute status.success?, output
      refute File.exist?(File.join(fixture[:root], "native/macos-arm64.sha"))
      assert_equal authentic, File.read(lock_path(fixture))
    end
  end

  def test_dirty_worktree_is_not_the_expected_lock
    native_fixture do |fixture, authentic|
      File.write(lock_path(fixture), authentic.sub("authentic", "forged"))
      output, status = reproduce(fixture)
      assert status.success?, output
      assert_equal authentic.sub("authentic", "forged"), File.read(lock_path(fixture))
    end
  end

  def test_forged_native_checksum_is_rejected
    reject_mutation { |text| text.sub("authentic", "forged") }
  end

  def test_forged_native_provenance_is_rejected
    reject_mutation { |text| text.sub("provenance_verified = false", "provenance_verified = true") }
  end

  def test_stale_platform_independent_metadata_is_rejected
    reject_mutation { |text| text.sub("backend = \"github:test/tool\"", "backend = \"github:other/tool\"") }
  end

  def test_omitted_native_record_is_rejected
    reject_mutation { |text| text.sub(/\[tools\.tool\."platforms.macos-arm64"\].*?\n\n/m, "") }
  end

  def test_duplicate_record_is_rejected
    reject_mutation { |text| text + text.sub("lockfile_version = 1\n\n", "") }
  end

  def test_failed_native_command_cannot_issue_a_receipt
    native_fixture do |fixture, _|
      File.write(File.join(fixture[:source], "tools/ci/lock_native_platform.sh"), "exit 1\n")
      output, status = reproduce(fixture)
      refute status.success?, output
      refute File.exist?(File.join(fixture[:root], "native/macos-arm64.sha"))
    end
  end

  def test_successful_noop_native_command_cannot_accept_submitted_data
    native_fixture do |fixture, _|
      File.write(File.join(fixture[:source], "tools/ci/lock_native_platform.sh"), "exit 0\n")
      output, status = reproduce(fixture)
      refute status.success?, output
      refute File.exist?(File.join(fixture[:root], "native/macos-arm64.sha"))
    end
  end

  private

  def reject_mutation
    native_fixture do |fixture, expected|
      changed = yield expected
      refute_equal expected, changed
      File.write(lock_path(fixture), changed)
      fixture_commit(fixture[:agent])
      output, status = reproduce(fixture)
      refute status.success?, output
      assert_equal changed, File.read(lock_path(fixture))
      refute File.exist?(File.join(fixture[:root], "native/macos-arm64.sha"))
    end
  end

  def native_fixture
    publication_fixture do |fixture|
      native = "lockfile_version = 1\n\n[[tools.tool]]\nversion = \"1.0\"\nbackend = \"github:test/tool\"\nspecifiers = [\"1.0\"]\n\n[tools.tool.\"platforms.macos-arm64\"]\nchecksum = \"authentic\"\nprovenance_verified = false\n\n"
      File.write(lock_path(fixture), native)
      fixture_commit(fixture[:agent])
      File.write(File.join(fixture[:root], "canonical.lock"), native)
      File.write(File.join(fixture[:source], "tools/ci/lock_native_platform.sh"), "cp '#{fixture[:root]}/canonical.lock' \"$2/files/home/.config/mise/mise.lock\"\n")
      yield fixture, native
    end
  end

  def lock_path(fixture)
    File.join(fixture[:agent], "files/home/.config/mise/mise.lock")
  end

  def reproduce(fixture, platform = "macos-arm64")
    Open3.capture2e({"BUNDLE_GEMFILE" => File.expand_path("../../Gemfile", __dir__)}, "bundle", "exec", "ruby", File.join(fixture[:source], "tools/ci/reproduce_mise_lock.rb"), platform, File.join(fixture[:root], "native"), chdir: fixture[:agent])
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
