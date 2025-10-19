require "test_helper"

class InstallFontsStepTest < Minitest::Test
  def test_should_not_run_in_ci
    ENV["CI"] = "true"

    step = create_step(Dotfiles::Step::InstallFontsStep)
    refute step.should_run?
  ensure
    ENV.delete("CI")
  end

  def test_should_not_run_in_noninteractive
    ENV["NONINTERACTIVE"] = "true"

    step = create_step(Dotfiles::Step::InstallFontsStep)
    refute step.should_run?
  ensure
    ENV.delete("NONINTERACTIVE")
  end
end
