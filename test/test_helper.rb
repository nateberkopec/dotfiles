$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "dotfiles"
require "minitest/autorun"
require "minitest/pride"
require_relative "support/fake_system_adapter"

ENV.delete("CI")
ENV.delete("NONINTERACTIVE")
# In tests, we use FakeSystemAdapter to control all system interactions.
# The CI/NONINTERACTIVE env vars cause steps to skip certain operations
# (like sudo commands) and always return complete?=true, which prevents
# us from testing the actual step logic. In production, these env vars
# protect against running interactive prompts in automated environments.

class Minitest::Test
  def setup
    @fake_system = FakeSystemAdapter.new
    @dotfiles_dir = "/tmp/dotfiles"
    @home = "/tmp/home"
    @fixtures_dir = File.expand_path("fixtures", __dir__)
  end

  def create_step(step_class, **overrides)
    defaults = {
      debug: false,
      dotfiles_repo: "https://github.com/test/dotfiles.git",
      dotfiles_dir: @dotfiles_dir,
      home: @home,
      system: @fake_system
    }
    step_class.new(**defaults.merge(overrides))
  end

  def stub_default_paths(step)
    step.config.paths = {
      "application_paths" => {
        "ghostty_config_dir" => "#{@home}/Library/Application Support/com.mitchellh.ghostty",
        "ghostty_config_file" => "#{@home}/Library/Application Support/com.mitchellh.ghostty/config"
      },
      "home_paths" => {
        "aerospace_config" => "#{@home}/.aerospace.toml",
        "gitconfig" => "#{@home}/.gitconfig"
      },
      "dotfiles_sources" => {
        "ghostty_config" => "files/ghostty/config",
        "aerospace_config" => "files/aerospace/.aerospace.toml",
        "git_config" => "files/git/.gitconfig"
      }
    }
  end
end
