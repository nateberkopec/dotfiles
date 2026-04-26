class Dotfiles
  class Runner
    PROGRESS_MUTEX = Mutex.new

    def initialize(log_file = nil)
      Dotfiles.log_file = log_file
      @debug = ENV["DEBUG"] == "true"
      @config = Config.new(Dotfiles.determine_dotfiles_dir)
      @step_classes = Dotfiles::Step.all_steps
      @step_instances = nil
    end

    def run
      start_time = Time.now
      Dotfiles.debug "Starting macOS development environment setup..."
      execute_all_steps
      log_total_time(start_time)
    rescue => e
      abort "Error: #{e.message}"
    end

    def execute_all_steps
      @step_instances = instantiate_steps(build_step_params)
      run_steps_in_parallel
      check_completion
    end

    private

    def build_step_params
      {
        debug: @debug,
        dotfiles_repo: @config.dotfiles_repo,
        dotfiles_dir: @config.dotfiles_dir,
        home: @config.home
      }
    end

    def instantiate_steps(step_params)
      @step_classes.map { |step_class| step_class.new(**step_params) }
    end

    def log_total_time(start_time)
      elapsed = ((Time.now - start_time) * 1000).round(2)
      Dotfiles.debug "Total run time: #{elapsed}ms"
    end

    def run_steps_in_parallel
      context = parallel_step_context
      spawn_step_threads(context).each(&:join)
      puts ""
      raise context[:error] if context[:error]
    end

    def parallel_step_context
      {completed_steps: {}, mutex: Mutex.new, condition: ConditionVariable.new, error: nil}
    end

    def spawn_step_threads(context)
      @step_instances.each_with_index.map do |step, index|
        Thread.new { execute_step_when_ready(step, index, context) }
      end
    end

    def execute_step_when_ready(step, index, context)
      step_class = @step_classes[index]
      return unless wait_for_dependencies(step_class, context)

      execute_single_step(step, index)
      mark_step_complete(step_class, context)
    rescue => e
      record_step_error(e, context)
    end

    def execute_single_step(step, index)
      step_class = @step_classes[index]

      if should_run_step?(step, step_class)
        run_step(step, step_class)
      else
        skip_step(step_class)
      end
    end

    def should_run_step?(step, step_class)
      return false unless step.allowed_on_platform?

      Dotfiles.debug_benchmark("Should run step: #{step_class.display_name}") { step.should_run? }
    end

    def run_step(step, step_class)
      Dotfiles.debug "Running step: #{step_class.display_name}"
      print_progress "X"
      step.instance_variable_set(:@ran, true)
      Dotfiles.debug_benchmark("Step: #{step_class.display_name}") { step.run }
    end

    def skip_step(step_class)
      print_progress "."
      Dotfiles.debug_benchmark("Step (skipped): #{step_class.display_name}") {}
    end

    def print_progress(character)
      progress_mutex.synchronize { printf character }
    end

    def progress_mutex
      PROGRESS_MUTEX
    end

    def wait_for_dependencies(step_class, context)
      context[:mutex].synchronize do
        wait_until_ready(step_class, context)
        context[:error].nil?
      end
    end

    def wait_until_ready(step_class, context)
      until dependencies_complete?(step_class, context) || context[:error]
        context[:condition].wait(context[:mutex])
      end
    end

    def dependencies_complete?(step_class, context)
      step_class.depends_on.all? { |dep| context[:completed_steps].key?(dep) }
    end

    def mark_step_complete(step_class, context)
      context[:mutex].synchronize do
        context[:completed_steps][step_class] = true
        context[:condition].broadcast
      end
    end

    def record_step_error(error, context)
      context[:mutex].synchronize do
        context[:error] ||= error
        context[:condition].broadcast
      end
    end

    def check_completion
      Dotfiles.debug_benchmark("Completion check") do
        results = collect_step_results
        OutputFormatter.new(results).display
      end
    end

    def collect_step_results
      mutex, results = Mutex.new, empty_results
      spawn_result_threads(mutex, results).each(&:join)
      puts ""
      results[:table_data] = results[:table_data].sort_by(&:first).map { |row| row.drop(1) }
      results
    end

    def empty_results
      {failed_steps: [], table_data: [], warnings: [], notices: [], errors: []}
    end

    def spawn_result_threads(mutex, results)
      @step_classes.each_with_index.map do |step_class, i|
        Thread.new { collect_single_step_result(step_class, i, mutex, results) }
      end
    end

    def collect_single_step_result(step_class, index, mutex, results)
      step_data = build_step_data(step_class, index)
      mutex.synchronize do
        printf "."
        merge_step_result(step_data, results)
      end
    end

    def build_step_data(step_class, index)
      step = @step_instances[index]
      step_name = step_class.display_name
      complete = if step.allowed_on_platform?
        Dotfiles.debug_benchmark("Complete check: #{step_name}") { !!step.complete? }
      else
        true
      end
      {index: index, name: step_name, complete: complete, step: step}
    end

    def merge_step_result(data, results)
      append_table_row(data, results)
      append_failed_step(data, results)
      append_step_messages(data, results)
    end

    def append_table_row(data, results)
      results[:table_data] << [data[:index], data[:name], data[:complete] ? "✓" : "✗", table_row_ran(data)]
    end

    def table_row_ran(data)
      data[:step].ran? ? "Yes" : "No"
    end

    def append_failed_step(data, results)
      results[:failed_steps] << data[:name] unless data[:complete]
    end

    def append_step_messages(data, results)
      results[:warnings].concat(data[:step].warnings)
      results[:notices].concat(data[:step].notices)
      append_step_errors(data, results)
    end

    def append_step_errors(data, results)
      results[:errors].concat(data[:step].errors.map { |err| {step: data[:name], message: err} })
    end
  end
end
