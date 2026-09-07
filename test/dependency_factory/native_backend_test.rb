require "test_helper"
require_relative "../../tools/ci/dependency_factory"
require_relative "../support/dependency_publication_fixture"

# standard:disable Dotfiles/BanFileSystemClasses
class DependencyNativeBackendTest < Minitest::Test
  include DependencyPublicationFixture

  def test_linux_eza_keeps_vfox_identity_without_seeding_generated_values
    publication_fixture do |fixture|
      linux = {"url" => "https://github.com/eza-community/eza/releases/download/v0.23.5/eza_x86_64-unknown-linux-gnu.tar.gz"}
      record = {"version" => "0.23.5", "backend" => "vfox:eza", "platforms.linux-x64" => linux}
      native = TomlRB.dump({"tools" => {"eza" => [record]}})
      aqua = Marshal.load(Marshal.dump(record))
      aqua["backend"] = "aqua:eza-community/eza"
      aqua["platforms.linux-x64"].merge!("checksum" => "sha256:35c70c5c43c29108075e58b893234c67ef585f0b53a7eaf8e9e7d4eec9f339b4", "url_api" => "https://api.github.com/repos/eza-community/eza/releases/assets/471228887")
      File.write(File.join(fixture[:root], "aqua.lock"), TomlRB.dump({"tools" => {"eza" => [aqua]}}))
      File.write(File.join(fixture[:root], "vfox.lock"), native)
      record["platforms.macos-arm64"] = {"url" => "https://github.com/cargo-bins/cargo-quickinstall/releases/download/eza-0.23.5/eza-0.23.5-aarch64-apple-darwin.tar.gz"}
      expected = TomlRB.dump({"tools" => {"eza" => [record]}})
      lock = File.join(fixture[:agent], "files/home/.config/mise/mise.lock")
      File.write(lock, expected)
      fixture_commit(fixture[:agent])
      File.write(File.join(fixture[:root], "expected.lock"), expected)
      command = File.join(fixture[:source], "tools/ci/lock_native_platform.sh")
      File.write(command, <<~SH)
        set -eu
        lock="$2/files/home/.config/mise/mise.lock"
        if [ -f "$2/pass" ]; then
          cmp '#{fixture[:root]}/expected.lock' "$lock"
        else
          ! grep -Eq 'url|checksum|provenance|platforms' "$lock"
          if grep -q 'vfox:eza' "$lock"; then backend=vfox; else backend=aqua; fi
          cp "#{fixture[:root]}/$backend.lock" "$lock"
          touch "$2/pass"
        fi
      SH
      File.write(lock, "")
      output, status = Open3.capture2e("bash", command, "linux-x64", fixture[:agent])
      assert status.success?, output
      assert_includes File.read(lock), 'backend = "aqua:eza-community/eza"'
      File.write(lock, expected)
      output, status = Open3.capture2e({"BUNDLE_GEMFILE" => File.expand_path("../../Gemfile", __dir__)}, "bundle", "exec", "ruby", File.join(fixture[:source], "tools/ci/reproduce_mise_lock.rb"), "linux-x64", File.join(fixture[:root], "native"), chdir: fixture[:agent])
      assert status.success?, output
      assert_equal expected, File.read(lock)
      assert_equal "#{fixture_git(fixture[:agent], "rev-parse", "HEAD")}\n", File.read(File.join(fixture[:root], "native/linux-x64.sha"))
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
