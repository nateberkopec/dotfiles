require_relative "system_assertions"
require_relative "config_fixture_helper"
require_relative "defaults_test_helper"

class StepTestCase < Minitest::Test
  include SystemAssertions
  include ConfigFixtureHelper
  include DefaultsTestHelper

  class << self
    def step_class(klass = nil)
      @step_class = klass if klass
      @step_class
    end
  end

  def setup
    super
    raise ArgumentError, "StepTestCase subclasses must declare step_class" unless self.class.step_class
  end

  def step(overrides = {})
    if overrides.empty?
      @step ||= build_step
    else
      build_step(overrides)
    end
  end

  def rebuild_step!(overrides = {})
    @step = build_step(overrides)
  end

  def assert_complete(current_step = step)
    assert current_step.complete?, "Expected #{self.class.step_class} to be complete. Errors: #{current_step.errors.join(", ")}"
  end

  def assert_incomplete(current_step = step)
    refute current_step.complete?, "Expected #{self.class.step_class} to be incomplete"
  end

  def assert_should_run(current_step = step)
    assert current_step.should_run?, "Expected #{self.class.step_class}#should_run? to be true"
  end

  def refute_should_run(current_step = step)
    refute current_step.should_run?, "Expected #{self.class.step_class}#should_run? to be false"
  end

  private

  def build_step(overrides = {})
    create_step(self.class.step_class, **step_overrides.merge(overrides))
  end

  def step_overrides
    {}
  end
end
