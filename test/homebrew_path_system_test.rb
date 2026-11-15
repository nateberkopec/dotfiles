require "test_helper"
require "tmpdir"

class HomebrewPathSystemTest < Minitest::Test
  SCRIPT = File.expand_path("../files/home/.config/bash/safety.bash", __dir__)

  def test_noninteractive_bash_finds_homebrew_commands_without_overriding_existing_paths
    Dir.mktmpdir("homebrew-path") do |home|
      bin = File.join(home, ".homebrew/bin")
      sbin = File.join(home, ".homebrew/sbin")
      preferred = File.join(home, "preferred")
      FileUtils.mkdir_p([bin, sbin, preferred])
      write_command(bin, "dotfiles-brew-command")
      write_command(sbin, "dotfiles-brew-service")
      write_command(bin, "dotfiles-brew-override")
      write_command(preferred, "dotfiles-brew-override")
      env = {"HOME" => home, "PATH" => "#{preferred}:/usr/bin:/bin", "BASH_ENV" => SCRIPT}
      command = <<~'SH'
        source "$BASH_ENV"
        command -v dotfiles-brew-command
        command -v dotfiles-brew-service
        command -v dotfiles-brew-override
        printf '%s\n' "$PATH"
      SH
      output, status = Open3.capture2e(env, "/bin/bash", "--noprofile", "--norc", "-c", command,
        chdir: home, unsetenv_others: true)
      assert status.success?, output
      lines = output.lines.map(&:chomp)
      assert_equal [File.join(bin, "dotfiles-brew-command"), File.join(sbin, "dotfiles-brew-service"),
        File.join(preferred, "dotfiles-brew-override")], lines.first(3)
      paths = lines.last.split(":")
      assert_equal 1, paths.count(bin)
      assert_equal 1, paths.count(sbin)
    end
  end

  private

  def write_command(directory, name)
    path = File.join(directory, name)
    File.write(path, "#!/bin/sh\nexit 0\n")
    File.chmod(0o755, path)
  end
end
