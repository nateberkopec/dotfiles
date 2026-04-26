require "test_helper"
require "shellwords"

class InstallFishShellStepTest < StepTestCase
  step_class Dotfiles::Step::InstallFishShellStep

  def test_depends_on_mise_tools
    assert_equal [Dotfiles::Step::InstallMiseToolsStep], self.class.step_class.depends_on
  end

  def test_should_run_when_mise_would_install_fish
    @fake_system.stub_macos
    stub_mise_available
    @fake_system.stub_command(macos_install_command(dry_run: true), "mise fish ⇢ would install")

    assert_should_run
  end

  def test_run_installs_macos_fish_app_and_links_cli_binaries
    @fake_system.stub_macos
    stub_mise_available
    stub_macos_installed_binaries
    @fake_system.stub_command(macos_install_command, "")
    @fake_system.stub_command(where_command, macos_install_prefix)

    step.run

    assert_executed(macos_install_command)
    assert_command_run(:mkdir_p, local_bin_dir)
    assert_macos_binaries_linked
  end

  def test_complete_when_fish_is_linked
    @fake_system.stub_macos
    @fake_system.stub_symlink(fish_link_path, macos_binary("fish"))

    assert_complete
  end

  def test_linux_uses_matching_release_asset_for_architecture
    @fake_system.stub_linux
    stub_mise_available
    @fake_system.stub_command("uname -m", "x86_64")
    @fake_system.stub_command(linux_install_command(dry_run: true), "mise fish ⇢ would install")

    assert_should_run
    assert_executed(linux_install_command(dry_run: true), quiet: true)
  end

  def test_run_installs_linux_fish_binary_and_links_it
    @fake_system.stub_linux
    stub_mise_available
    @fake_system.stub_command("uname -m", "aarch64")
    @fake_system.stub_file_content(File.join(linux_install_prefix, "fish"), "binary")
    @fake_system.stub_command(linux_install_command(arch: "aarch64"), "")
    @fake_system.stub_command(where_command, linux_install_prefix)

    step.run

    assert_executed(linux_install_command(arch: "aarch64"))
    assert_command_run(:create_symlink, File.join(linux_install_prefix, "fish"), fish_link_path)
  end

  private

  def stub_mise_available
    @fake_system.stub_command("command -v mise >/dev/null 2>&1", "")
  end

  def assert_macos_binaries_linked
    %w[fish fish_indent fish_key_reader].each do |name|
      assert_command_run(:create_symlink, macos_binary(name), File.join(local_bin_dir, name))
    end
  end

  def stub_macos_installed_binaries
    %w[fish fish_indent fish_key_reader].each do |name|
      @fake_system.stub_file_content(macos_binary(name), "binary")
    end
  end

  def macos_install_prefix
    File.join(@home, ".local", "share", "mise", "installs", "github-fish-shell-fish-shell", "4.6.0")
  end

  def linux_install_prefix
    File.join(@home, ".local", "share", "mise", "installs", "github-fish-shell-fish-shell", "4.6.0")
  end

  def local_bin_dir
    File.join(@home, ".local", "bin")
  end

  def fish_link_path
    File.join(local_bin_dir, "fish")
  end

  def macos_binary(name)
    File.join(macos_install_prefix, "fish-4.6.0.app", "Contents", "Resources", "base", "usr", "local", "bin", name)
  end

  def macos_install_command(dry_run: false)
    install_command(macos_spec, dry_run: dry_run)
  end

  def linux_install_command(arch: "x86_64", dry_run: false)
    install_command(linux_spec(arch), dry_run: dry_run)
  end

  def install_command(spec, dry_run: false)
    command = "mise --cd #{@home.shellescape} install --yes"
    command = "#{command} --dry-run" if dry_run
    "#{command} #{spec.shellescape}"
  end

  def where_command
    "mise --cd #{@home.shellescape} where github:fish-shell/fish-shell@latest"
  end

  def macos_spec
    "github:fish-shell/fish-shell[asset_pattern=fish-{{version}}.app.zip]@latest"
  end

  def linux_spec(arch)
    "github:fish-shell/fish-shell[asset_pattern=fish-{{version}}-linux-#{arch}.tar.xz]@latest"
  end
end
