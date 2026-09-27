require "test_helper"
require_relative "support/bootstrap_script_helper"

# standard:disable Dotfiles/BanFileSystemClasses
class PrivateHomebrewBootstrapTest < Minitest::Test
  include BootstrapScriptHelper

  def test_fresh_clone_records_freshness_for_homebrew_auto_update
    with_bootstrap_stub do |env|
      run_private_install(env)

      fetch_head = File.join(env.fetch("HOME"), ".homebrew", ".git", "FETCH_HEAD")
      assert File.exist?(fetch_head)
      assert_operator File.mtime(fetch_head), :>, Time.now - 60
    end
  end

  def test_existing_clone_keeps_its_old_update_timestamp
    with_bootstrap_stub do |env|
      fetch_head = File.join(env.fetch("HOME"), ".homebrew", ".git", "FETCH_HEAD")
      FileUtils.mkdir_p(File.dirname(fetch_head))
      File.write(fetch_head, "previous fetch\n")
      old = Time.at(1_000_000)
      File.utime(old, old, fetch_head)

      run_private_install(env)

      assert_equal old, File.mtime(fetch_head)
      assert_equal "previous fetch\n", File.read(fetch_head)
    end
  end

  private

  def run_private_install(env)
    run_bootstrap_commands(env, nil, <<~BASH)
      git() { mkdir -p "$HOME/.homebrew/.git"; }
      install_private_homebrew
    BASH
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
