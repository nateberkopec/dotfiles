require "test_helper"
require "open3"
require "tmpdir"

# standard:disable Dotfiles/BanFileSystemClasses
class UnprotectNoSudoTest < Minitest::Test
  def test_no_sudo_reports_immutable_files_without_elevating
    Dir.mktmpdir do |home|
      source = File.join(home, ".dotfiles", "files", "home", ".gem", "credentials")
      target = File.join(home, ".gem", "credentials")
      [source, target].each do |path|
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "fixture")
      end
      hook = File.expand_path("../bin/lib/unprotect-managed-files.sh", __dir__)
      script = <<~BASH
        uname() { echo Darwin; }
        chflags() { return 1; }
        sudo() { echo "SUDO WAS CALLED"; exit 93; }
        source #{Shellwords.escape(hook)}
      BASH
      output, status = Open3.capture2e({"HOME" => home, "DOTF_NO_SUDO" => "1"}, "bash", "-c", script)

      refute status.success?
      assert_includes output, "requires sudo to clear immutable flags"
      refute_includes output, "SUDO WAS CALLED"
      assert_equal "fixture", File.read(target)
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
