require "test_helper"

class RunnerTest < Minitest::Test
  def test_runner_initialization
    runner = Dotfiles::Runner.new

    assert_equal File.expand_path("~/.dotfiles"), runner.dotfiles_dir
    assert_equal ENV["HOME"], runner.home
    refute_nil runner.dotfiles_repo
  end

  def test_runner_reads_dotfiles_repo_from_config
    runner = Dotfiles::Runner.new

    # Should read from config or use default
    assert runner.dotfiles_repo.include?("github.com")
    assert runner.dotfiles_repo.include?("dotfiles")
  end
end
