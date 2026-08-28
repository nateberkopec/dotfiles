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
      launchctl_trace = File.join(dir, "launchctl.log")
      mise_trace = File.join(dir, "mise.log")
      bin = File.join(dir, "bin")

      FileUtils.mkdir_p([File.dirname(plist), bin])
      File.write(plist, "legacy")
      write_command(bin, "uname", "echo Darwin")
      write_command(bin, "mise", 'echo "$*" >> "$MISE_TRACE"')
      write_command(bin, "launchctl", 'echo "$*" >> "$LAUNCHCTL_TRACE"')

      _stdout, stderr, status = Open3.capture3(
        {
          "HOME" => home,
          "PATH" => "#{bin}:#{ENV.fetch("PATH")}",
          "LAUNCHCTL_TRACE" => launchctl_trace,
          "MISE_TRACE" => mise_trace
        },
        "bash", script
      )

      assert status.success?, stderr
      refute File.exist?(plist)
      assert_equal "bootout gui/#{Process.uid}/com.user.woodblock-wallpaper\n", File.read(launchctl_trace)
      assert_equal <<~TRACE, File.read(mise_trace)
        install pipx
        install pipx:playwright
        exec -- playwright install chromium-headless-shell
      TRACE
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
