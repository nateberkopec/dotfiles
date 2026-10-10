# standard:disable Dotfiles/BanFileSystemClasses -- black-box script test requires real temporary files
require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class PostDotfilesHookTest < Minitest::Test
  def test_removes_legacy_wallpaper_agent_when_orbstack_is_absent
    assert_hook_removes_agents(admin: true)
  end

  def test_removes_omniwm_agent_for_non_admin_user
    assert_hook_removes_agents(admin: false)
  end

  private

  def assert_hook_removes_agents(admin:)
    Dir.mktmpdir do |dir|
      home = File.join(dir, "home")
      plist = File.join(home, "Library/LaunchAgents/com.user.woodblock-wallpaper.plist")
      launchctl_trace = File.join(dir, "launchctl.log")
      mise_trace = File.join(dir, "mise.log")
      ruby_trace = File.join(dir, "ruby.log")
      bin = File.join(dir, "bin")
      hook_source = File.join(home, ".dotfiles/files/home/.git-hooks/pre-push")
      sync_script = File.join(home, ".dotfiles/bin/lib/sync-git-hooks.sh")

      FileUtils.mkdir_p([File.dirname(plist), File.dirname(hook_source), File.dirname(sync_script), bin])
      File.write(plist, "legacy")
      omniwm_plist = File.join(home, "Library/LaunchAgents/dev.mise.omniwm.plist")
      File.write(omniwm_plist, "managed")
      File.write(hook_source, "managed hook")
      FileUtils.cp(File.expand_path("../bin/lib/sync-git-hooks.sh", __dir__), sync_script)
      write_command(bin, "uname", "echo Darwin")
      write_command(bin, "id", 'if [ "$1" = "-Gn" ]; then echo ' + (admin ? '"staff admin"' : '"staff"') + '; else /usr/bin/id "$@"; fi')
      write_command(bin, "mise", '[ "$*" = "hook-env -s bash" ] || echo "$*" >> "$MISE_TRACE"')
      write_command(bin, "launchctl", 'echo "$*" >> "$LAUNCHCTL_TRACE"')
      write_command(bin, "ruby", 'echo "$*" >> "$RUBY_TRACE"')

      _stdout, stderr, status = Open3.capture3(
        {
          "HOME" => home,
          "PATH" => "#{bin}:#{ENV.fetch("PATH")}",
          "LAUNCHCTL_TRACE" => launchctl_trace,
          "MISE_TRACE" => mise_trace,
          "RUBY_TRACE" => ruby_trace
        },
        "bash", script
      )

      assert status.success?, stderr
      refute File.exist?(plist)
      expected_launchctl = "bootout gui/#{Process.uid}/com.user.woodblock-wallpaper\n"
      expected_launchctl += "bootout gui/#{Process.uid}/dev.mise.omniwm\n" unless admin
      assert_equal expected_launchctl, File.read(launchctl_trace)
      assert_equal admin, File.exist?(omniwm_plist)
      refute File.exist?(mise_trace)
      assert_equal "#{home}/.dotfiles/bin/lib/install-meridian-pi-scrub.rb\n", File.read(ruby_trace)
      assert_equal "managed hook", File.read(File.join(home, ".git-hooks/pre-push"))
    end
  end

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
