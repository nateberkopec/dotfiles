require "test_helper"
require "date"
require_relative "support/bootstrap_script_helper"

# standard:disable Dotfiles/BanFileSystemClasses
class BootstrapTest < Minitest::Test
  include BootstrapScriptHelper

  MISE_RUBY_COMPILE_WORKAROUND_REMOVE_BY = Date.new(2026, 8, 1)

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

  def test_prepare_debian_apt_sources_installs_missing_keys_and_sources
    with_bootstrap_stub do |env|
      run_prepare_debian_apt_sources(env)

      expected_urls = [
        "https://raw.githubusercontent.com/eza-community/eza/main/deb.asc",
        "https://mise.jdx.dev/gpg-key.pub"
      ]
      assert_equal expected_urls, File.readlines(env.fetch("APT_CURL_LOG"), chomp: true)
      %w[gierens mise].each do |name|
        assert File.exist?(File.join(env.fetch("DEBIAN_KEYRING_DIR"), "#{name}-archive-keyring.gpg"))
        assert_equal apt_source_line(name) + "\n", File.read(File.join(env.fetch("DEBIAN_SOURCE_DIR"), "#{name}.list"))
      end
    end
  end

  def test_prepare_debian_apt_sources_preserves_existing_keys_and_sources
    with_bootstrap_stub do |env|
      FileUtils.mkdir_p([env.fetch("DEBIAN_KEYRING_DIR"), env.fetch("DEBIAN_SOURCE_DIR")])
      %w[gierens mise].each do |name|
        File.write(File.join(env.fetch("DEBIAN_KEYRING_DIR"), "#{name}-archive-keyring.gpg"), "existing")
        File.write(File.join(env.fetch("DEBIAN_SOURCE_DIR"), "#{name}.list"), apt_source_line(name) + "\n")
      end

      run_prepare_debian_apt_sources(env)

      refute File.exist?(env.fetch("APT_CURL_LOG"))
      refute File.exist?(env.fetch("APT_SUDO_LOG"))
    end
  end

  def test_bootstrap_mise_sets_ruby_compile_false
    with_bootstrap_stub do |env|
      write_mise_stub(env)
      run_bootstrap_mise(env)

      assert_includes logged_mise_commands(env), "mise activate bash"
      assert_includes logged_mise_commands(env), "mise settings set ruby.compile false"
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
    end
  end

  def test_mise_ruby_compile_workaround_expires
    assert Date.today < MISE_RUBY_COMPILE_WORKAROUND_REMOVE_BY,
      "Remove bootstrap's ruby.compile workaround; mise 2026.8.0 should make this default."
  end

  private

  def apt_source_line(name)
    repo = (name == "gierens") ? "http://deb.gierens.de" : "https://mise.jdx.dev/deb"
    "deb [signed-by=/usr/share/keyrings/#{name}-archive-keyring.gpg] #{repo} stable main"
  end

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
