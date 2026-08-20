require "test_helper"
require_relative "support/bootstrap_script_helper"

# standard:disable Dotfiles/BanFileSystemClasses
class BootstrapTest < Minitest::Test
  include BootstrapScriptHelper

  def test_ensure_dotfiles_checkout_links_repo_when_target_is_missing
    with_bootstrap_stub do |env|
      target = File.join(env.fetch("HOME"), ".dotfiles")

      run_ensure_dotfiles_checkout(env)

      assert File.symlink?(target)
      assert_equal File.expand_path("..", __dir__), File.readlink(target)
    end
  end

  def test_ensure_dotfiles_checkout_preserves_an_existing_entry
    with_bootstrap_stub do |env|
      target = File.join(env.fetch("HOME"), ".dotfiles")
      File.symlink("missing-checkout", target)

      run_ensure_dotfiles_checkout(env)

      assert_equal "missing-checkout", File.readlink(target)
    end
  end

  def test_homebrew_installer_mode
    homebrew_installer_scenarios.each do |scenario|
      with_bootstrap_stub do |env|
        run_install_homebrew(env.merge(scenario[:env]), terminal: scenario[:terminal])

        assert_equal scenario[:expected], installed_mode(env)
      end
    end
  end

  def test_homebrew_installer_runs_noninteractively_when_stdio_is_not_a_terminal
    with_bootstrap_stub do |env|
      run_install_homebrew_without_terminal(env)

      assert_equal "1", installed_mode(env)
    end
  end

  def test_bootstrap_homebrew_exercises_fresh_admin_missing_brew_path
    fresh_homebrew_scenarios.each do |scenario|
      with_bootstrap_stub do |env|
        run_bootstrap_homebrew(env, terminal: scenario[:terminal])

        assert_equal scenario[:expected], installed_mode(env)
        assert_equal env.fetch("HOMEBREW_INSTALLED_BREW"), configured_brew(env)
      end
    end
  end

  def test_bootstrap_mise_installs_the_pinned_version_on_a_fresh_machine
    with_bootstrap_stub do |env|
      run_bootstrap_mise(env)

      assert_equal "2026.8.2 #{File.join(env.fetch("HOME"), ".local", "bin", "mise")}", File.read(env.fetch("MISE_INSTALL_LOG")).chomp
    end
  end

  def test_bootstrap_mise_replaces_an_unpinned_self_managed_version
    with_bootstrap_stub do |env|
      write_self_managed_mise_stub(env, "2026.8.9")

      run_bootstrap_mise(env)

      assert_match(/\A2026\.8\.2 /, File.read(env.fetch("MISE_INSTALL_LOG")))
    end
  end

  def test_bootstrap_mise_seeds_global_config_before_activation
    with_bootstrap_stub do |env|
      global_config = File.join(env.fetch("HOME"), ".config", "mise", "config.toml")
      FileUtils.mkdir_p(File.dirname(global_config))
      File.write(global_config, "stale config\n")
      write_mise_stub(env)

      run_bootstrap_mise(env)

      expected = File.read(File.expand_path("../files/home/.config/mise/config.toml", __dir__))
      assert_equal expected, File.read(env.fetch("MISE_CONFIG_AT_ACTIVATION_LOG"))
      assert File.exist?(File.join(env.fetch("HOME"), ".config", "mise", "mise.lock"))
    end
  end

  private

  def homebrew_installer_scenarios
    [
      {terminal: true, env: {}, expected: "__unset__"},
      {terminal: true, env: {"CI" => "true"}, expected: "1"},
      {terminal: true, env: {"NONINTERACTIVE" => "true"}, expected: "1"},
      {terminal: false, env: {}, expected: "1"}
    ]
  end

  def fresh_homebrew_scenarios
    [
      {terminal: true, expected: "__unset__"},
      {terminal: false, expected: "1"}
    ]
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
