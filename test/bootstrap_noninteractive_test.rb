require "test_helper"
require "open3"
require_relative "support/bootstrap_script_helper"

# standard:disable Dotfiles/BanFileSystemClasses
class BootstrapNoninteractiveTest < Minitest::Test
  include BootstrapScriptHelper

  def test_noninteractive_does_not_install_homebrew_or_debian_prerequisites
    %w[1 true].each do |mode|
      with_bootstrap_stub do |env|
        script = <<~BASH
          source #{Shellwords.escape(bootstrap_path)}
          is_macos() { return 0; }
          is_linux() { return 0; }
          user_has_admin_rights() { return 0; }
          resolve_homebrew_bin() { return 1; }
          install_homebrew() { exit 91; }
          install_private_homebrew() { exit 92; }
          sudo() { exit 93; }
          bootstrap_homebrew
          bootstrap_debian_prereqs
        BASH
        output, status = Open3.capture2e(env.merge("NONINTERACTIVE" => mode), "bash", "-c", script)
        assert status.success?, output
        refute File.exist?(env.fetch("HOMEBREW_INSTALL_ENV_LOG"))
      end
    end
  end

  def test_noninteractive_preserves_the_private_homebrew_prefix
    with_bootstrap_stub do |env|
      private_brew = File.join(env.fetch("HOME"), ".homebrew", "bin", "brew")
      global_brew = File.join(env.fetch("PATH").split(":").first, "brew")
      [private_brew, global_brew].each do |path|
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "#!/bin/sh\nexit 0\n")
        FileUtils.chmod("+x", path)
      end
      script = <<~BASH
        source #{Shellwords.escape(bootstrap_path)}
        is_macos() { return 0; }
        user_has_admin_rights() { return 1; }
        install_homebrew() { exit 91; }
        install_private_homebrew() { exit 92; }
        configure_homebrew_shellenv() { echo "$1" > "$HOMEBREW_CONFIGURED_BREW_LOG"; }
        bootstrap_homebrew
      BASH
      output, status = Open3.capture2e(env.merge("NONINTERACTIVE" => "1"), "bash", "-c", script)
      assert status.success?, output
      assert_equal private_brew, configured_brew(env)
    end
  end

  def test_ci_without_noninteractive_still_installs_bootstrap_packages
    with_bootstrap_stub do |env|
      script = <<~BASH
        source #{Shellwords.escape(bootstrap_path)}
        is_macos() { return 0; }
        is_linux() { return 0; }
        user_has_admin_rights() { return 0; }
        install_homebrew() { echo "install-homebrew"; }
        resolve_homebrew_bin() { echo /bin/sh; }
        configure_homebrew_shellenv() { :; }
        sudo() { echo "sudo $*"; }
        bootstrap_homebrew
        bootstrap_debian_prereqs
      BASH
      output, status = Open3.capture2e(env.merge("CI" => "true"), "bash", "-c", script)
      assert status.success?, output
      assert_includes output, "install-homebrew"
      assert_includes output, "sudo apt-get update"
      assert_includes output, "sudo env DEBIAN_FRONTEND=noninteractive apt-get install"
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
