# standard:disable Dotfiles/BanFileSystemClasses -- black-box script test requires real temporary files
require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class PostDefaultsHookTest < Minitest::Test
  def test_restarts_preference_and_ui_processes_after_defaults_drift
    Dir.mktmpdir do |dir|
      home = File.join(dir, "home")
      marker = File.join(dir, "dotf-defaults-changed-#{Process.uid}")
      trace = File.join(dir, "killall.log")
      bin = File.join(dir, "bin")
      FileUtils.mkdir_p([home, bin])
      File.write(marker, "")
      write_command(bin, "uname", "echo Darwin")
      write_command(bin, "defaults", 'printf "%s\n" "$HOME/Documents/Inbox"')
      write_command(bin, "killall", 'echo "$*" >> "$TRACE"')

      _stdout, stderr, status = Open3.capture3(
        {
          "HOME" => home,
          "PATH" => "#{bin}:/usr/bin:/bin",
          "TMPDIR" => dir,
          "TRACE" => trace
        },
        "bash",
        script
      )

      assert status.success?, stderr
      refute File.exist?(marker)
      assert_equal "cfprefsd\nDock\nFinder\nSystemUIServer\n", File.read(trace)
    end
  end

  private

  def script
    File.expand_path("../bin/lib/post-defaults-hook.sh", __dir__)
  end

  def write_command(bin, name, body)
    path = File.join(bin, name)
    File.write(path, "#!/bin/sh\n#{body}\n")
    FileUtils.chmod(0o755, path)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
