require "test_helper"
require "open3"
require_relative "support/bootstrap_script_helper"

# standard:disable Dotfiles/BanFileSystemClasses
class DotfNoSudoTest < Minitest::Test
  include BootstrapScriptHelper

  def test_no_sudo_defers_migrations_packages_and_full_run_marker
    with_dotf_script do |dir, script, _logs|
      File.write(File.join(dir, "bin", "bootstrap"), "#!/bin/bash\n[ \"$DOTF_NO_SUDO:$NONINTERACTIVE\" = 1:1 ]\n")
      FileUtils.chmod("+x", File.join(dir, "bin", "bootstrap"))
      state = File.join(dir, "state", "dotfiles")
      FileUtils.mkdir_p(state)
      File.write(File.join(state, "last-run-sha"), "previous\n")
      File.write(File.join(state, "needs-run"), "dotf run\n")
      command = <<~BASH
        source #{Shellwords.escape(script)}
        export HOME=#{Shellwords.escape(dir)} XDG_STATE_HOME=#{Shellwords.escape(File.join(dir, "state"))}
        export DOTF_LOCK_DIR=#{Shellwords.escape(File.join(dir, "lock"))}
        ensure_homebrew_env() { :; }
        ensure_mise_env() { :; }
        user_has_admin_rights() { return 0; }
        is_debian() { return 1; }
        mise() { echo "mise $*"; }
        ruby() { echo "ruby $*"; }
        git() { echo new-sha; }
        cmd_run --no-sudo
      BASH
      output, status = Open3.capture2e({"DEBUG" => "true", "DOTF_NO_SUDO" => nil}, "bash", "-c", command)

      assert status.success?, output
      assert_includes output, "--skip packages"
      refute_includes output, "MigrationRunner"
      assert_includes output, "Dotfiles::Runner"
      assert_includes output, "privileged work"
      assert_equal "previous\n", File.read(File.join(state, "last-run-sha"))
      assert File.exist?(File.join(state, "needs-run"))
    end
  end

  def test_unknown_run_options_fail_before_bootstrap
    with_dotf_script do |_dir, script, _logs|
      ["--sudo", "--no-sudo extra"].each do |options|
        output, status = Open3.capture2e("bash", script, "run", *options.split)
        refute status.success?
        assert_includes output, "Error:"
      end
    end
  end

  def test_no_sudo_bootstrap_does_not_install_homebrew_or_debian_prerequisites
    with_bootstrap_stub do |env|
      script = <<~BASH
        source #{Shellwords.escape(bootstrap_path)}
        is_macos() { return 0; }
        is_linux() { return 0; }
        resolve_homebrew_bin() { :; }
        install_homebrew() { exit 91; }
        install_private_homebrew() { exit 92; }
        sudo() { exit 93; }
        bootstrap_homebrew
        bootstrap_debian_prereqs
      BASH
      output, status = Open3.capture2e(env.merge("DOTF_NO_SUDO" => "1"), "bash", "-c", script)
      assert status.success?, output
      refute File.exist?(env.fetch("HOMEBREW_INSTALL_ENV_LOG"))
    end
  end

  def test_privileged_package_steps_skip_in_no_sudo_mode
    [Dotfiles::Step::InstallBrewCasksStep, Dotfiles::Step::InstallDebianDesktopAppsStep, Dotfiles::Step::SetFishDefaultShellStep].each do |klass|
      with_env("DOTF_NO_SUDO" => "1", "NONINTERACTIVE" => nil) do
        step = create_step(klass)
        refute step.should_run?
        step.run
        assert step.complete?
        refute @fake_system.operations.any? { |operation, command, _| operation == :execute && command.include?("sudo") }
      end
    end
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
