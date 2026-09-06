require "test_helper"
require "open3"
require "tmpdir"

# standard:disable Dotfiles/BanFileSystemClasses
class SafetyEnvironmentTest < Minitest::Test
  SCRIPT = File.expand_path("../../files/home/.config/bash/safety.bash", __dir__)

  def setup
    bash_installed = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
      File.executable?(File.join(directory, "bash"))
    end
    skip "Bash is not installed" unless bash_installed
  end

  def test_applies_safety_defaults_without_recursive_bash_startup
    Dir.mktmpdir("bash-safety") do |tmpdir|
      bin = File.join(tmpdir, "bin")
      shims = File.join(tmpdir, "aube-shims")
      loads = File.join(tmpdir, "bash-env-loads")
      startup_env = File.join(tmpdir, "startup-env")
      bash_env = File.join(tmpdir, "bash-env")
      FileUtils.mkdir_p([bin, shims])
      write_bounded_bash_env(bash_env)
      write_executable(bin, "mise", <<~SH)
        #!/bin/bash
        [[ -z "${BASH_ENV:-}" ]] && state=unset || state=set
        printf 'mise:%s\\n' "$state" >> "$STARTUP_ENV_LOG"
        echo 'export MISE_SAFETY_ACTIVE=1'
      SH
      write_executable(bin, "aube", <<~SH)
        #!/bin/bash
        [[ -z "${BASH_ENV:-}" ]] && state=unset || state=set
        printf 'aube:%s\\n' "$state" >> "$STARTUP_ENV_LOG"
        printf 'export AUBE_SHIM_DIR=%q\\n' "$AUBE_TEST_SHIM_DIR"
      SH
      write_executable(bin, "sfw", "#!/bin/sh\nprintf 'sfw:%s\\n' \"$*\"\n")
      write_executable(shims, "npx", "#!/bin/sh\n")

      env = {
        "BASH_ENV" => bash_env,
        "BASH_SAFETY_SCRIPT" => SCRIPT,
        "BASH_SAFETY_LOADS" => loads,
        "STARTUP_ENV_LOG" => startup_env,
        "AUBE_TEST_SHIM_DIR" => shims,
        "SOCKET_FIREWALL_DISABLE" => nil,
        "PATH" => [bin, "/usr/bin", "/bin", shims].join(":")
      }
      command = "printf '%s\\n' \"$MISE_SAFETY_ACTIVE\" \"$MISE_SHELL\" \"$(command -v npx)\"; cargo install demo"
      output, status = Open3.capture2e(env, "bash", "--noprofile", "--norc", "-c", command)

      assert status.success?, output
      assert_equal "1", File.read(loads).chomp, "BASH_ENV loaded recursively"
      assert_equal ["mise:unset", "aube:unset"], File.readlines(startup_env, chomp: true)
      assert_equal ["1", "bash", File.join(shims, "npx"), "sfw:cargo install demo"], output.lines.map(&:chomp)
    end
  end

  private

  def write_bounded_bash_env(path)
    File.write(path, <<~'SH')
      loads=0
      if [[ -f "$BASH_SAFETY_LOADS" ]]; then
        read -r loads < "$BASH_SAFETY_LOADS"
      fi
      ((loads += 1))
      printf '%s\n' "$loads" > "$BASH_SAFETY_LOADS"
      if ((loads > 4)); then
        exit 90
      fi
      source "$BASH_SAFETY_SCRIPT"
    SH
  end

  def write_executable(directory, name, contents)
    path = File.join(directory, name)
    File.write(path, contents)
    FileUtils.chmod("u+x", path)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
