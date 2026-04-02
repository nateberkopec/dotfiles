class Dotfiles
  class Runner
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
      run_steps_serially
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

    def run_steps_serially
      completed_steps = {}
      @step_instances.each_with_index do |step, index|
        execute_single_step(step, index, completed_steps)
      end
      puts ""
    end

    def execute_single_step(step, index, completed_steps)
      step_class = @step_classes[index]
      wait_for_dependencies(step_class, completed_steps)

      if should_run_step?(step, step_class)
        run_step(step, step_class)
      else
        skip_step(step_class)
      end

      completed_steps[step_class] = true
    end

    def should_run_step?(step, step_class)
      return false unless step.allowed_on_platform?

      Dotfiles.debug_benchmark("Should run step: #{step_class.display_name}") { step.should_run? }
    end

    def run_step(step, step_class)
      Dotfiles.debug "Running step: #{step_class.display_name}"
      printf "X"
      step.instance_variable_set(:@ran, true)
      Dotfiles.debug_benchmark("Step: #{step_class.display_name}") { step.run }
    end

    def skip_step(step_class)
      printf "."
      Dotfiles.debug_benchmark("Step (skipped): #{step_class.display_name}") {}
    end

    def wait_for_dependencies(step_class, completed_steps)
      step_class.depends_on.each { |dep| sleep 0.01 until completed_steps.key?(dep) }
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
