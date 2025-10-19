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
    @dotfiles_dir = File.expand_path("../test/fixtures", __dir__)
    @home = "/tmp/home"
    @config = Dotfiles::Config.new(@dotfiles_dir, home_directory: @home, debug: false)
  end

  def create_step(step_class, config: nil, system: nil, dotfiles_dir: nil)
    # Allow tests to override dotfiles_dir by creating a new config
    if dotfiles_dir
      config = Dotfiles::Config.new(dotfiles_dir, home_directory: @home, debug: false)
    end
    step_class.new(config: config || @config, system: system || @fake_system)
  end
end
