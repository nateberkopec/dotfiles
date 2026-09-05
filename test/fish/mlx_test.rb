require "test_helper"
require "open3"
require "shellwords"
require "tmpdir"

# standard:disable Dotfiles/BanFileSystemClasses
class MlxTest < Minitest::Test
  FUNCTION_PATH = File.expand_path("../../files/home/.config/fish/functions/mlx.fish", __dir__)

  def setup
    skip "Fish is not installed" unless system("fish", "--version", out: File::NULL)
  end

  def test_runs_latest_scoped_npm_tool_with_release_age_exclusion
    output = run_mlx("npm:@earendil-works/pi-coding-agent", "mlx pi --model astra", "existing")

    assert_includes output, "age=0s"
    assert_includes output, "exclude=existing,@earendil-works/*"
    assert_includes output, "args=<x><npm:@earendil-works/pi-coding-agent@latest><--><pi><--model><astra>"
  end

  def test_runs_latest_non_npm_tool_without_aube_exclusion
    output = run_mlx("github:cli/cli", "mlx gh --version")

    assert_includes output, "age=0s"
    assert_includes output, "exclude=<unset>"
    assert_includes output, "args=<x><github:cli/cli@latest><--><gh><--version>"
  end

  def test_requires_a_command
    output, status = Open3.capture2e("fish", "--no-config", "--command", "source #{Shellwords.escape(FUNCTION_PATH)}; mlx")

    refute status.success?
    assert_equal "Usage: mlx COMMAND [ARGUMENTS...]\n", output
  end

  private

  def run_mlx(tool, command, exclusion = nil)
    Dir.mktmpdir("mlx-test") do |dir|
      mise = File.join(dir, "mise")
      File.write(mise, fake_mise)
      FileUtils.chmod("+x", mise)
      env = {
        "PATH" => "#{dir}:#{ENV.fetch("PATH")}",
        "FAKE_MISE_TOOL" => tool,
        "AUBE_MINIMUM_RELEASE_AGE_EXCLUDE" => exclusion
      }
      output, status = Open3.capture2e(env, "fish", "--no-config", "--command", "source #{Shellwords.escape(FUNCTION_PATH)}; #{command}")
      assert status.success?, output
      output
    end
  end

  def fake_mise
    <<~SH
      #!/bin/sh
      if [ "$1" = "which" ]; then
        printf '%s\n' "$FAKE_MISE_TOOL"
        exit
      fi
      printf 'age=%s\n' "${MISE_MINIMUM_RELEASE_AGE-<unset>}"
      printf 'exclude=%s\n' "${AUBE_MINIMUM_RELEASE_AGE_EXCLUDE-<unset>}"
      printf 'args='; printf '<%s>' "$@"; printf '\n'
    SH
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
