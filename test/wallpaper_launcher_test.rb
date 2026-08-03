# standard:disable Dotfiles/BanFileSystemClasses -- black-box script test requires real temporary files
require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class WallpaperLauncherTest < Minitest::Test
  def test_derives_home_and_runs_wallpaper_command_without_inherited_home
    Dir.mktmpdir do |home|
      launcher = File.join(home, ".local/share/dotfiles/launch-woodblock-wallpaper")
      command = File.join(home, ".local/bin/set-woodblock-wallpaper")
      trace = File.join(home, "trace")
      FileUtils.mkdir_p([File.dirname(launcher), File.dirname(command)])
      FileUtils.cp(launcher_source, launcher)
      File.write(command, <<~SH)
        #!/bin/sh
        printf 'HOME=%s\nPATH=%s\nARGS=%s\n' "$HOME" "$PATH" "$*" > "$TRACE"
      SH
      FileUtils.chmod(0o755, [launcher, command])

      _stdout, stderr, status = Open3.capture3(
        {"HOME" => nil, "PATH" => "/usr/bin:/bin", "TRACE" => trace},
        launcher,
        "one",
        "two"
      )

      assert status.success?, stderr
      assert_equal <<~TRACE, File.read(trace)
        HOME=#{home}
        PATH=#{home}/.local/share/mise/shims:/usr/bin:/bin
        ARGS=one two
      TRACE
    end
  end

  def test_rejects_an_unexpected_install_path
    Dir.mktmpdir do |dir|
      launcher = File.join(dir, "launch-woodblock-wallpaper")
      FileUtils.cp(launcher_source, launcher)
      FileUtils.chmod(0o755, launcher)

      _stdout, stderr, status = Open3.capture3({"HOME" => nil, "PATH" => "/usr/bin:/bin"}, launcher)

      refute status.success?
      assert_includes stderr, "must run from ~/.local/share/dotfiles/launch-woodblock-wallpaper"
    end
  end

  private

  def launcher_source
    File.expand_path("../files/home/.local/share/dotfiles/launch-woodblock-wallpaper", __dir__)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
