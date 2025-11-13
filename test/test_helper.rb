$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "dotfiles"
require "minitest/autorun"
require "minitest/pride"
require "yaml"
require_relative "support/fake_system_adapter"
require_relative "support/system_assertions"
require_relative "support/config_fixture_helper"
require_relative "support/step_test_case"

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

  def with_ci
    ENV["CI"] = "true"
    yield
  ensure
    ENV.delete("CI")
  end
end
