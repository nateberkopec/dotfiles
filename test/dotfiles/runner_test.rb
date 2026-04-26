require "test_helper"

class RunnerTest < Minitest::Test
  FakeStep = Struct.new(:allowed, :complete_value, :should_run_value, :warnings, :notices, :errors, :run_calls, :should_run_calls, :complete_calls, keyword_init: true) do
    def initialize(**kwargs)
      super
      self.warnings ||= []
      self.notices ||= []
      self.errors ||= []
      self.run_calls ||= 0
      self.should_run_calls ||= 0
      self.complete_calls ||= 0
    end

    def allowed_on_platform?
      allowed
    end

    def should_run?
      self.should_run_calls += 1
      should_run_value.respond_to?(:call) ? should_run_value.call : should_run_value
    end

    def run
      self.run_calls += 1
    end

    def complete?
      self.complete_calls += 1
      complete_value
    end

    def ran?
      instance_variable_get(:@ran) || run_calls.positive?
    end
  end

  def test_run_steps_serially_rechecks_should_run_after_dependency_runs
    first_class = build_step_class("First")
    second_class = build_step_class("Second", [first_class])

    first_step = FakeStep.new(allowed: true, complete_value: true, should_run_value: true)
    second_step = FakeStep.new(
      allowed: true,
      complete_value: true,
      should_run_value: -> { first_step.ran? }
    )

    runner = build_runner([first_class, second_class], [first_step, second_step])

    capture_io { runner.send(:run_steps_serially) }

    assert_equal 1, first_step.run_calls
    assert_equal 1, second_step.run_calls
    assert_equal 1, second_step.should_run_calls
  end

  def test_run_steps_serially_skips_steps_not_allowed_on_platform
    step_class = build_step_class("Skipped")
    step = FakeStep.new(allowed: false, complete_value: true, should_run_value: true)
    runner = build_runner([step_class], [step])

    capture_io { runner.send(:run_steps_serially) }

    assert_equal 0, step.run_calls
    assert_equal 0, step.should_run_calls
  end

  def test_doctor_completion_check_reports_without_running_steps
    step_class = build_step_class("Doctor")
    step = FakeStep.new(allowed: true, complete_value: false, should_run_value: true)
    formatter = build_formatter_class
    runner = build_runner([step_class], [step], formatter)

    capture_io { runner.send(:check_completion, context: :doctor) }

    assert_equal 1, step.complete_calls
    assert_equal 0, step.should_run_calls
    assert_equal 0, step.run_calls
    assert_equal :doctor, formatter.last_context
    assert_equal [["Doctor", "✗", "No"]], formatter.last_results[:table_data]
  end

  private

  def build_formatter_class
    Class.new do
      class << self
        attr_accessor :last_context, :last_results
      end

      def initialize(results, context: :run)
        @results = results
        @context = context
      end

      def display
        self.class.last_context = @context
        self.class.last_results = @results
      end
    end
  end

  def build_runner(step_classes, step_instances, formatter_class = Dotfiles::OutputFormatter)
    runner = Dotfiles::Runner.allocate
    runner.instance_variable_set(:@step_classes, step_classes)
    runner.instance_variable_set(:@step_instances, step_instances)
    runner.instance_variable_set(:@formatter_class, formatter_class)
    runner
  end

  def build_step_class(name, dependencies = [])
    Class.new do
      define_singleton_method(:display_name) { name }
      define_singleton_method(:depends_on) { dependencies }
    end
  end
end
