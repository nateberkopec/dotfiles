# standard:disable Dotfiles/BanFileSystemClasses -- black-box script test requires real temporary files
require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class PostDotfilesHookTest < Minitest::Test
  def test_removes_legacy_wallpaper_agent_when_orbstack_is_absent
    Dir.mktmpdir do |dir|
      home = File.join(dir, "home")
      plist = File.join(home, "Library/LaunchAgents/com.user.woodblock-wallpaper.plist")
      trace = File.join(dir, "launchctl.log")
      bin = File.join(dir, "bin")

      FileUtils.mkdir_p([File.dirname(plist), bin])
      File.write(plist, "legacy")
      write_command(bin, "uname", "echo Darwin")
      write_command(bin, "mise", "exit 0")
      write_command(bin, "launchctl", 'echo "$*" >> "$TRACE"')

      _stdout, stderr, status = Open3.capture3(
        {"HOME" => home, "PATH" => "#{bin}:#{ENV.fetch("PATH")}", "TRACE" => trace},
        "bash", script
      )

      assert status.success?, stderr
      refute File.exist?(plist)
      assert_equal "bootout gui/#{Process.uid}/com.user.woodblock-wallpaper\n", File.read(trace)
    end
  end

  private

  def script
    File.expand_path("../bin/lib/post-dotfiles-hook.sh", __dir__)
  end

  def write_command(bin, name, body)
    path = File.join(bin, name)
    File.write(path, "#!/bin/sh\n#{body}\n")
    FileUtils.chmod(0o755, path)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
