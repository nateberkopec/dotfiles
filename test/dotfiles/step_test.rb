require "test_helper"

class StepTest < Minitest::Test
  class TestStepA < Dotfiles::Step
    def run
    end

    def complete?
      super
      true
    end
  end

  class TestStepB < Dotfiles::Step
    def self.depends_on
      [TestStepA]
    end

    def run
    end

    def complete?
      super
      true
    end
  end

  class TestStepC < Dotfiles::Step
    def self.depends_on
      [TestStepB]
    end

    def run
    end

    def complete?
      super
      true
    end
  end

  class TestStepCamelCaseExample < Dotfiles::Step
    def run
    end

    def complete?
      super
      true
    end
  end

  class NewTestStep < Dotfiles::Step
    def run
    end

    def complete?
      super
      true
    end
  end

  def test_display_name_strips_module_namespace
    # Nested test classes include the test class name, so we check that it strips properly
    assert_includes TestStepA.display_name, "Test Step A"
    assert_includes TestStepB.display_name, "Test Step B"
  end

  def test_display_name_handles_camel_case
    assert_includes TestStepCamelCaseExample.display_name, "Test Step Camel Case Example"
  end

  def test_topological_sort_orders_by_dependencies
    steps = [TestStepC, TestStepA, TestStepB]
    sorted = Dotfiles::Step.topological_sort(steps)

    assert_equal TestStepA, sorted[0]
    assert_equal TestStepB, sorted[1]
    assert_equal TestStepC, sorted[2]
  end

  def test_step_registration_via_inheritance
    assert_includes Dotfiles::Step.all_steps, NewTestStep
  end

  def test_warnings_collection
    step = create_step(TestStepA)
    step.add_warning(title: "Test Warning", message: "This is a test")

    assert_equal 1, step.warnings.length
    assert_equal "Test Warning", step.warnings.first[:title]
    assert_equal "This is a test", step.warnings.first[:message]
  end

  def test_notices_collection
    step = create_step(TestStepA)
    step.add_notice(title: "Test Notice", message: "This is a notice")

    assert_equal 1, step.notices.length
    assert_equal "Test Notice", step.notices.first[:title]
    assert_equal "This is a notice", step.notices.first[:message]
  end

  def test_ran_tracking
    step = create_step(TestStepA)
    refute step.ran?

    step.instance_variable_set(:@ran, true)
    assert step.ran?
  end

  def test_should_run_returns_opposite_of_complete
    step = create_step(TestStepA)
    assert step.complete?
    refute step.should_run?
  end

  def test_errors_collection
    step = create_step(TestStepA)
    step.add_error("First error")
    step.add_error("Second error")

    assert_equal 2, step.errors.length
    assert_equal "First error", step.errors[0]
    assert_equal "Second error", step.errors[1]
  end

  def test_errors_cleared_on_complete_check
    step = create_step(TestStepA)
    step.add_error("Stale error")
    step.complete?

    assert_empty step.errors
  end
end
