require "test_helper"
require "open3"
require "tmpdir"

# standard:disable Dotfiles/BanFileSystemClasses
class SafetyEnvironmentTest < Minitest::Test
  SCRIPT = File.expand_path("../../files/home/.config/bash/safety.bash", __dir__)

  def setup
    skip "Bash is not installed" unless system("bash", "--version", out: File::NULL)
  end

  def test_applies_safety_defaults_to_noninteractive_bash
    Dir.mktmpdir("bash-safety") do |tmpdir|
      bin = File.join(tmpdir, "bin")
      shims = File.join(tmpdir, "aube-shims")
      FileUtils.mkdir_p(bin)
      FileUtils.mkdir_p(shims)
      write_executable(bin, "mise", <<~SH)
        #!/bin/sh
        echo 'export MISE_SAFETY_ACTIVE=1'
      SH
      write_executable(bin, "aube", <<~SH)
        #!/bin/sh
        echo 'export AUBE_SHIM_DIR=#{shims}'
      SH
      write_executable(bin, "sfw", <<~SH)
        #!/bin/sh
        printf 'sfw:%s\\n' "$*"
      SH
      write_executable(shims, "npx", "#!/bin/sh\n")

      path = [bin, "/usr/bin", "/bin", shims].join(":")
      command = "printf '%s\\n' \"$MISE_SAFETY_ACTIVE\" \"$MISE_SHELL\" \"$(command -v npx)\"; cargo install demo"
      output, status = Open3.capture2e({"BASH_ENV" => SCRIPT, "PATH" => path}, "bash", "--noprofile", "--norc", "-c", command)

      assert status.success?, output
      assert_equal ["1", "bash", File.join(shims, "npx"), "sfw:cargo install demo"], output.lines.map(&:chomp)
    end
  end

  private

  def write_executable(directory, name, contents)
    path = File.join(directory, name)
    File.write(path, contents)
    FileUtils.chmod("u+x", path)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
