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
      run_steps_serially(check_should_run_parallel)
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

    def check_should_run_parallel
      mutex, steps_to_run = Mutex.new, []
      spawn_should_run_threads(mutex, steps_to_run).each(&:join)
      puts ""
      steps_to_run
    end

    def spawn_should_run_threads(mutex, steps_to_run)
      @step_instances.each_with_index.map do |step, index|
        Thread.new { check_single_step_should_run(step, index, mutex, steps_to_run) }
      end
    end

    def check_single_step_should_run(step, index, mutex, steps_to_run)
      unless step.allowed_on_platform?
        mutex.synchronize { printf "." }
        return
      end

      should_run = Dotfiles.debug_benchmark("Should run step: #{@step_classes[index].display_name}") { step.should_run? }
      mutex.synchronize do
        printf "."
        steps_to_run << index if should_run
      end
    end

    def run_steps_serially(steps_to_run_indices)
      completed_steps = {}
      @step_instances.each_with_index do |step, index|
        execute_single_step(step, index, steps_to_run_indices, completed_steps)
      end
      puts ""
    end

    def execute_single_step(step, index, steps_to_run_indices, completed_steps)
      step_class = @step_classes[index]
      wait_for_dependencies(step_class, completed_steps)
      steps_to_run_indices.include?(index) ? run_step(step, step_class) : skip_step(step_class)
      completed_steps[step_class] = true
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
        result = collect_step_results
        display_results_table(result[:table_data])
        display_errors(result[:errors])
        display_warnings(result[:warnings])
        display_notices(result[:notices])
        display_final_status(result[:failed_steps])
      end
    end

    def collect_step_results
      mutex, results = Mutex.new, empty_results
      spawn_result_threads(mutex, results).each(&:join)
      puts ""
      results[:table_data] = results[:table_data].sort_by(&:first).map(&:last)
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
      results[:table_data] << [data[:index], table_row_status(data), table_row_ran(data)]
    end

    def table_row_status(data)
      "#{data[:name]},#{data[:complete] ? "✓" : "✗"}"
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

    def display_results_table(table_data)
      csv_data = "Step,Status,Ran?\n" + table_data.join("\n")
      IO.popen(["gum", "table", "--border", "rounded", "--widths", "25,8,8", "--print"], "w") { |io| io.write(csv_data) }
    end

    def display_errors(errors)
      return if errors.empty?
      errors.group_by { |err| err[:step] }.each { |step, errs| display_step_errors(step, errs) }
    end

    def display_step_errors(step_name, step_errors)
      message_lines = ["❌ #{step_name}", "", *step_errors.map { |err| "• #{err[:message]}" }]
      gum_style("#ff5555", message_lines)
    end

    def display_warnings(warnings)
      display_messages(warnings, "#ffaa00")
    end

    def display_notices(notices)
      display_messages(notices, "#00aaff")
    end

    def display_messages(messages, color)
      messages.each { |msg| gum_style(color, [msg[:title], "", msg[:message]]) }
    end

    def display_final_status(failed_steps)
      failed_steps.any? ? display_failure(failed_steps) : display_success
    end

    def display_failure(failed_steps)
      gum_style("#ff5555", ["❌ Installation Failed!", "", "Incomplete steps:", *failed_steps.map { |s| "• #{s}" }], border: "thick")
      exit 1
    end

    def display_success
      gum_style("#50fa7b", ["🎉 All Steps Complete!", "Setup successful"], width: 50)
    end

    def gum_style(color, lines, border: "rounded", width: 60)
      system("gum", "style", "--foreground", color, "--border", border, "--align", "left", "--width", width.to_s, "--margin", "1 0", "--padding", "1 2", *lines)
    end
  end
end
