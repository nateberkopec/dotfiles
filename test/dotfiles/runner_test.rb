require "test_helper"
require "timeout"
require_relative "../support/fake_runner_step"

class RunnerTest < Minitest::Test
  def test_run_steps_in_parallel_rechecks_should_run_after_dependency_runs
    first_class = build_step_class("First")
    second_class = build_step_class("Second", [first_class])
    first_finished = false
    first_step = fake_step(run_hook: -> { first_finished = true })
    second_step = fake_step(should_run_value: -> { first_finished })
    runner = build_runner([first_class, second_class], [first_step, second_step])

    capture_io { runner.send(:run_steps_in_parallel) }

    assert_equal 1, first_step.run_calls
    assert_equal 1, second_step.run_calls
    assert_equal 1, second_step.should_run_calls
  end

  def test_run_steps_in_parallel_runs_independent_steps_concurrently
    started = Queue.new
    release = Queue.new
    first_class = build_step_class("First")
    second_class = build_step_class("Second")
    first_step = blocking_step(started, release)
    second_step = blocking_step(started, release)
    runner = build_runner([first_class, second_class], [first_step, second_step])

    run_blocked_steps(runner, started, release)

    assert_equal 1, first_step.run_calls
    assert_equal 1, second_step.run_calls
  end

  def test_run_steps_in_parallel_skips_steps_not_allowed_on_platform
    step_class = build_step_class("Skipped")
    step = fake_step(allowed: false)
    runner = build_runner([step_class], [step])

    capture_io { runner.send(:run_steps_in_parallel) }

    assert_equal 0, step.run_calls
    assert_equal 0, step.should_run_calls
  end

  private

  def build_runner(step_classes, step_instances)
    runner = Dotfiles::Runner.allocate
    runner.instance_variable_set(:@step_classes, step_classes)
    runner.instance_variable_set(:@step_instances, step_instances)
    runner
  end

  def fake_step(**overrides)
    defaults = {
      allowed: true,
      complete_value: true,
      should_run_value: true
    }
    FakeRunnerStep.new(**defaults.merge(overrides))
  end

  def blocking_step(started, release)
    fake_step(
      run_hook: -> do
        started << true
        release.pop
      end
    )
  end

  def run_blocked_steps(runner, started, release)
    runner_thread = Thread.new { capture_io { runner.send(:run_steps_in_parallel) } }
    Timeout.timeout(2) { 2.times { started.pop } }
    release_steps(release)
    runner_thread.value
  ensure
    release_steps(release) if release
    runner_thread&.kill if runner_thread&.alive?
  end

  def release_steps(release)
    2.times { release << true }
  end

  def build_step_class(name, dependencies = [])
    Class.new do
      define_singleton_method(:display_name) { name }
      define_singleton_method(:depends_on) { dependencies }
    end
  end
end
