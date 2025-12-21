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

      step_params = build_step_params
      @step_instances = instantiate_steps(step_params)
      steps_to_run = check_should_run_parallel
      run_steps_serially(steps_to_run)
      check_completion

      log_total_time(start_time)
    rescue => e
      puts "Error: #{e.message}"
      exit 1
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
      mutex = Mutex.new
      steps_to_run = []
      threads = []

      @step_instances.each_with_index do |step, index|
        threads << Thread.new do
          step_class = @step_classes[index]

          should_run = Dotfiles.debug_benchmark("Should run step: #{step_class.display_name}") do
            step.should_run?
          end

          mutex.synchronize { printf "." }

          if should_run
            mutex.synchronize { steps_to_run << index }
          end
        end
      end

      threads.each(&:join)
      puts ""

      steps_to_run
    end

    def run_steps_serially(steps_to_run_indices)
      completed_steps = {}

      @step_instances.each_with_index do |step, index|
        step_class = @step_classes[index]

        wait_for_dependencies(step_class, completed_steps)

        if steps_to_run_indices.include?(index)
          Dotfiles.debug "Running step: #{step_class.display_name}"
          printf "X"
          step.instance_variable_set(:@ran, true)
          Dotfiles.debug_benchmark("Step: #{step_class.display_name}") do
            step.run
          end
        else
          printf "."
          Dotfiles.debug_benchmark("Step (skipped): #{step_class.display_name}") do
            # Step is already complete, no action needed
          end
        end

        completed_steps[step_class] = true
      end

      puts ""
    end

    def wait_for_dependencies(step_class, completed_steps)
      dependencies = step_class.depends_on
      return if dependencies.empty?

      loop do
        all_complete = dependencies.all? { |dep| completed_steps.key?(dep) }
        break if all_complete
        sleep 0.01
      end
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
      mutex = Mutex.new
      results = {failed_steps: [], table_data: [], warnings: [], notices: [], errors: []}
      threads = @step_classes.each_with_index.map do |step_class, i|
        Thread.new { collect_single_step_result(step_class, i, mutex, results) }
      end

      threads.each(&:join)
      puts ""

      results[:table_data] = results[:table_data].sort_by(&:first).map(&:last)
      results
    end

    def collect_single_step_result(step_class, index, mutex, results)
      step = @step_instances[index]
      step_name = step_class.display_name
      completion_status = Dotfiles.debug_benchmark("Complete check: #{step_name}") { !!step.complete? }

      mutex.synchronize { printf "." }

      status_symbol = completion_status ? "✓" : "✗"
      ran_status = step.ran? ? "Yes" : "No"

      mutex.synchronize do
        results[:table_data] << [index, "#{step_name},#{status_symbol},#{ran_status}"]
        results[:failed_steps] << step_name unless completion_status
        results[:warnings].concat(step.warnings)
        results[:notices].concat(step.notices)
        results[:errors].concat(step.errors.map { |err| {step: step_name, message: err} }) if step.errors.any?
      end
    end

    def display_results_table(table_data)
      csv_data = "Step,Status,Ran?\n" + table_data.join("\n")
      IO.popen(["gum", "table", "--border", "rounded", "--widths", "25,8,8", "--print"], "w") do |io|
        io.write(csv_data)
      end
    end

    def display_errors(errors)
      return if errors.empty?

      errors.group_by { |err| err[:step] }.each do |step_name, step_errors|
        error_list = step_errors.map { |err| "• #{err[:message]}" }
        message_lines = ["❌ #{step_name}", "", *error_list]
        system("gum", "style", "--foreground", "#ff5555", "--border", "rounded", "--align", "left", "--width", "60", "--margin", "1 0", "--padding", "1 2", *message_lines)
      end
    end

    def display_warnings(warnings)
      display_messages(warnings, "#ffaa00")
    end

    def display_notices(notices)
      display_messages(notices, "#00aaff")
    end

    def display_messages(messages, color)
      messages.each do |msg|
        message_lines = [msg[:title], "", msg[:message]]
        system("gum", "style", "--foreground", color, "--border", "rounded", "--align", "left", "--width", "60", "--margin", "1 0", "--padding", "1 2", *message_lines)
      end
    end

    def display_final_status(failed_steps)
      if failed_steps.any?
        system("gum", "style", "--foreground", "#ff5555", "--border", "thick", "--align", "center", "--width", "60", "--margin", "1 0", "--padding", "1 2", "❌ Installation Failed!", "", "Incomplete steps:", *failed_steps.map { |step| "• #{step}" })
        exit 1
      else
        system("gum", "style", "--foreground", "#50fa7b", "--border", "rounded", "--align", "center", "--width", "50", "--margin", "1 0", "--padding", "1 2", "🎉 All Steps Complete!", "Setup successful")
      end
    end
  end
end
