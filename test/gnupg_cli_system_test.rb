require "test_helper"
require "tmpdir"

class GnupgCliSystemTest < Minitest::Test
  def test_exposes_homebrew_gpg_without_replacing_user_commands
    Dir.mktmpdir("gnupg-cli") do |home|
      env = {"HOME" => home, "PATH" => "/usr/bin:/bin", "BASH_ENV" => ""}
      target = File.join(home, ".local/bin/gpg")
      run_hook(env)
      if RUBY_PLATFORM.include?("darwin") && File.executable?("/opt/homebrew/bin/gpg")
        assert_equal "/opt/homebrew/bin/gpg", File.readlink(target)
        File.unlink(target)
        File.symlink("/missing/old/gpg", target)
        2.times { run_hook(env) }
        assert_equal "/opt/homebrew/bin/gpg", File.readlink(target)
        output, status = Open3.capture2e(env.merge("PATH" => "#{home}/.local/bin:/usr/bin:/bin"),
          "/bin/bash", "-c", "command -v gpg && gpg --version", unsetenv_others: true)
        assert status.success?, output
        assert_equal target, output.lines.first.strip
        assert_includes output, "gpg (GnuPG)"
        File.unlink(target)
      else
        refute File.exist?(target)
        refute File.symlink?(target)
      end
      FileUtils.mkdir_p(File.dirname(target))
      File.write(target, "user-owned gpg")
      run_hook(env)
      assert_equal "user-owned gpg", File.read(target)
      refute File.symlink?(target)
    end
  end

  def test_does_not_link_homebrew_gpg_on_other_platforms
    Dir.mktmpdir("gnupg-cli") do |home|
      bin = File.join(home, "bin")
      FileUtils.mkdir_p(bin)
      File.write(File.join(bin, "uname"), "#!/bin/sh\nprintf '%s\\n' Linux\n")
      File.chmod(0o755, File.join(bin, "uname"))
      run_hook({"HOME" => home, "PATH" => "#{bin}:/usr/bin:/bin", "BASH_ENV" => ""})
      refute File.symlink?(File.join(home, ".local/bin/gpg"))
    end
  end

  private

  def run_hook(env)
    output, status = Open3.capture2e(env, "/bin/bash", File.expand_path("../bin/lib/link-homebrew-gpg.sh", __dir__), unsetenv_others: true)
    assert status.success?, output
  end
end
