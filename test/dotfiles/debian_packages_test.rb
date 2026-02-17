require "test_helper"

class DebianPackagesTest < Minitest::Test
  class Harness
    include Dotfiles::Step::DebianPackages

    attr_reader :commands, :sleeps

    def initialize(responses)
      @responses = responses
      @commands = []
      @sleeps = []
    end

    def execute(command, quiet: true)
      @commands << command
      @responses.shift || ["", 0]
    end

    def sudo_prefix
      "sudo "
    end

    def sleep(seconds)
      @sleeps << seconds
    end
  end

  def test_run_apt_retries_transient_network_errors
    harness = Harness.new([
      ["E: Failed to fetch https://repo.charm.sh/apt/files/gum.deb\nE: Unable to fetch some archives", 100],
      ["", 0]
    ])

    _output, status = harness.send(:run_apt, "apt-get install -y gum")

    assert_equal 0, status
    assert_equal 2, harness.commands.length
    assert_equal [3], harness.sleeps
  end

  def test_run_apt_does_not_retry_non_retryable_errors
    harness = Harness.new([
      ["E: Unable to locate package does-not-exist", 100],
      ["", 0]
    ])

    _output, status = harness.send(:run_apt, "apt-get install -y does-not-exist")

    assert_equal 100, status
    assert_equal 1, harness.commands.length
    assert_empty harness.sleeps
  end
end
