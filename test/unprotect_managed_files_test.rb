# standard:disable Dotfiles/BanFileSystemClasses -- black-box script test requires real temporary files
require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class UnprotectManagedFilesTest < Minitest::Test
  SCRIPT = File.expand_path("../bin/lib/unprotect-managed-files.sh", __dir__)

  def test_unprotects_identical_files_before_mise_copies_them
    Dir.mktmpdir do |dir|
      home = File.join(dir, "home")
      source = File.join(home, ".dotfiles/files/home/.aws/credentials")
      target = File.join(home, ".aws/credentials")
      trace = File.join(dir, "chflags.log")
      bin = File.join(dir, "bin")

      FileUtils.mkdir_p([File.dirname(source), File.dirname(target), bin])
      File.write(source, "same")
      File.write(target, "same")
      write_command(bin, "uname", "echo Darwin")
      write_command(bin, "chflags", 'echo "direct:$*" >> "$TRACE"; exit 1')
      write_command(bin, "sudo", 'echo "sudo:$*" >> "$TRACE"')

      _stdout, stderr, status = Open3.capture3(
        {"HOME" => home, "PATH" => "#{bin}:#{ENV.fetch("PATH")}", "TRACE" => trace},
        "bash", SCRIPT
      )

      assert status.success?, stderr
      assert_equal <<~TRACE, File.read(trace)
        direct:noschg,nouchg #{target}
        sudo:chflags noschg,nouchg #{target}
      TRACE
    end
  end

  private

  def write_command(bin, name, body)
    path = File.join(bin, name)
    File.write(path, "#!/bin/sh\n#{body}\n")
    FileUtils.chmod(0o755, path)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
