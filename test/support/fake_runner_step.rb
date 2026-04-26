class FakeRunnerStep < Struct.new(:allowed, :complete_value, :should_run_value, :warnings, :notices, :errors, :run_calls, :should_run_calls, :run_hook, keyword_init: true)
  def initialize(**kwargs)
    super
    self.warnings ||= []
    self.notices ||= []
    self.errors ||= []
    self.run_calls ||= 0
    self.should_run_calls ||= 0
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
    run_hook&.call
  end

  def complete?
    complete_value
  end

  def ran?
    instance_variable_get(:@ran) || run_calls.positive?
  end
end
