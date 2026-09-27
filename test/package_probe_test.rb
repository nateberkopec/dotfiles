require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

# standard:disable Dotfiles/BanFileSystemClasses
class PackageProbeTest < Minitest::Test
  SCRIPT = File.expand_path("../tools/ci/package_probe.sh", __dir__)

  def test_non_admin_with_no_private_homebrew_does_not_probe_system_homebrew
    with_probe do |env|
      assert_probe env, "assert_not_installed Homebrew duti brew_formula_installed"

      assert_empty File.read(env.fetch("PROBE_LOG"))
    end
  end

  def test_non_admin_checks_formulae_in_private_homebrew
    with_probe do |env|
      install_private_brew(env)

      assert_probe env, "assert_installed Homebrew duti brew_formula_installed"

      assert_equal "private list --formula duti\n", File.read(env.fetch("PROBE_LOG"))
    end
  end

  def test_non_admin_checks_casks_in_private_homebrew
    with_probe do |env|
      install_private_brew(env)

      assert_probe env, "assert_installed Homebrew ghostty brew_cask_installed"

      assert_equal "private list --cask ghostty\n", File.read(env.fetch("PROBE_LOG"))
    end
  end

  def test_admin_uses_system_homebrew_even_with_a_private_prefix
    with_probe do |env|
      install_private_brew(env)

      assert_probe env.merge("PROBE_GROUPS" => "staff admin"), "assert_installed Homebrew duti brew_formula_installed"

      assert_equal "system list --formula duti\n", File.read(env.fetch("PROBE_LOG"))
    end
  end

  private

  def with_probe
    Dir.mktmpdir("package-probe") do |home|
      log = File.join(home, "probe.log")
      File.write(log, "")
      yield({"HOME" => home, "PROBE_LOG" => log, "PROBE_GROUPS" => "staff"})
    end
  end

  def install_private_brew(env)
    path = File.join(env.fetch("HOME"), ".homebrew", "bin", "brew")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#!/bin/bash\necho \"private $*\" >> \"$PROBE_LOG\"\n")
    File.chmod(0o755, path)
  end

  def assert_probe(env, command)
    script = <<~BASH
      set -euo pipefail
      source "$1"
      uname() { echo Darwin; }
      id() { echo "$PROBE_GROUPS"; }
      brew() { echo "system $*" >> "$PROBE_LOG"; }
      #{command}
    BASH
    output, status = Open3.capture2e(env, "/bin/bash", "-c", script, "probe", SCRIPT)
    assert status.success?, output
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
