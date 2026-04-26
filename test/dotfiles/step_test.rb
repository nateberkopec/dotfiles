require "test_helper"
require "stringio"

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

  class DescribedTestStep < Dotfiles::Step
    DESCRIPTION = "Does a test thing.".freeze

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
    assert_collection(:warnings, :add_warning, title: "Test Warning", message: "This is a test")
  end

  def test_notices_collection
    assert_collection(:notices, :add_notice, title: "Test Notice", message: "This is a notice")
  end

  def test_description_comes_from_class_constant
    assert_equal "Does a test thing.", DescribedTestStep.description
  end

  def test_print_steps_includes_class_name_and_description
    output = StringIO.new

    Dotfiles::Step.print_steps(output)

    assert_includes output.string, "StepTest::DescribedTestStep"
    assert_includes output.string, "Does a test thing."
  end

  def test_production_steps_define_descriptions
    missing = production_steps.reject do |step|
      step.const_defined?(:DESCRIPTION, false) && !step.description.empty?
    end

    assert_empty missing.map(&:name)
  end

  private

  def production_steps
    Dotfiles::Step.all_steps.select { |step| step.name&.start_with?("Dotfiles::Step::") }
  end

  def assert_collection(collection_method, add_method, title:, message:)
    step = create_step(TestStepA)
    step.send(add_method, title: title, message: message)

    collection = step.send(collection_method)
    assert_equal 1, collection.length
    assert_equal title, collection.first[:title]
    assert_equal message, collection.first[:message]
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

class TopologicalSortDuplicateRegressionTest < Minitest::Test
  class SharedDependency < Dotfiles::Step
    def run
    end

    def complete?
      super
      true
    end
  end

  class SharedDependent1 < Dotfiles::Step
    def self.depends_on
      [SharedDependency]
    end

    def run
    end

    def complete?
      super
      true
    end
  end

  class SharedDependent2 < Dotfiles::Step
    def self.depends_on
      [SharedDependency]
    end

    def run
    end

    def complete?
      super
      true
    end
  end

  # Regression test: steps with shared dependencies should not appear multiple times
  def test_topological_sort_does_not_duplicate_shared_dependencies
    steps = [SharedDependent1, SharedDependent2, SharedDependency]
    sorted = Dotfiles::Step.topological_sort(steps)

    assert_equal 3, sorted.length
    assert_equal 1, sorted.count(SharedDependency)
  end
end
