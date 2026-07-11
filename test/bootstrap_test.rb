require "test_helper"
require "date"
require_relative "support/bootstrap_script_helper"

# standard:disable Dotfiles/BanFileSystemClasses
class BootstrapTest < Minitest::Test
  include BootstrapScriptHelper

  MISE_RUBY_COMPILE_WORKAROUND_REMOVE_BY = Date.new(2026, 8, 1)

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

  def test_bootstrap_mise_uses_precompiled_rubies_and_seeds_global_config
    with_bootstrap_stub do |env|
      write_mise_stub(env)
      run_bootstrap_commands(env, nil, <<~'BASH')
        bootstrap_mise
        printf 'MISE_RUBY_COMPILE=%s\n' "$MISE_RUBY_COMPILE" >> "$MISE_COMMAND_LOG"
      BASH

      assert_includes logged_mise_commands(env), "mise activate bash"
      assert_includes logged_mise_commands(env), "MISE_RUBY_COMPILE=false"
      assert File.exist?(File.join(env.fetch("HOME"), ".config", "mise", "config.toml"))
    end
  end

  def test_mise_ruby_compile_workaround_expires
    assert Date.today < MISE_RUBY_COMPILE_WORKAROUND_REMOVE_BY,
      "Remove bootstrap's ruby.compile workaround; mise 2026.8.0 should make this default."
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
