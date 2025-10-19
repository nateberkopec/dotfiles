$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "dotfiles"
require "minitest/autorun"
require_relative "support/fake_system_adapter"

class Minitest::Test
  def setup
    @fake_system = FakeSystemAdapter.new
    @dotfiles_dir = "/tmp/dotfiles"
    @home = "/tmp/home"
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
end
