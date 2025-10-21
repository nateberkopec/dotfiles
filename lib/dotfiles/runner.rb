require "concurrent"

class Dotfiles
  class Runner
    attr_reader :dotfiles_repo, :dotfiles_dir, :home

    def initialize
      @debug = ENV["DEBUG"] == "true"
      @dotfiles_dir = File.expand_path("~/.dotfiles")
      @home = ENV["HOME"]
      @config = Config.new(@dotfiles_dir)
      @dotfiles_repo = @config.dotfiles_repo
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
        dotfiles_repo: @dotfiles_repo,
        dotfiles_dir: @dotfiles_dir,
        home: @home
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
      pool = Concurrent::FixedThreadPool.new(10)
      steps_to_run = Concurrent::Array.new

      @step_instances.each_with_index do |step, index|
        pool.post do
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

      pool.shutdown
      pool.wait_for_termination
      puts ""

      steps_to_run.to_a
    end

    def run_steps_serially(steps_to_run_indices)
      completed_steps = Set.new

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

        completed_steps.add(step_class)
      end

      puts ""
    end

    def wait_for_dependencies(step_class, completed_steps)
      dependencies = step_class.depends_on
      return if dependencies.empty?

      loop do
        all_complete = dependencies.all? { |dep| completed_steps.include?(dep) }
        break if all_complete
        sleep 0.01
      end
    end

    def check_completion
      Dotfiles.debug_benchmark("Completion check") do
        result = collect_step_results
        display_results_table(result[:table_data])
        display_warnings(result[:warnings])
        display_notices(result[:notices])
        display_final_status(result[:failed_steps])
      end
    end

    def collect_step_results
      mutex = Mutex.new
      failed_steps = Concurrent::Array.new
      table_data = Concurrent::Array.new
      warnings = Concurrent::Array.new
      notices = Concurrent::Array.new
      pool = Concurrent::FixedThreadPool.new(10)

      @step_classes.each_with_index do |step_class, i|
        pool.post do
          step = @step_instances[i]
          step_name = step_class.display_name
          completion_status = Dotfiles.debug_benchmark("Complete check: #{step_name}") do
            !!step.complete?
          end

          mutex.synchronize { printf "." }

          status_symbol = completion_status ? "✓" : "✗"
          ran_status = step.ran? ? "Yes" : "No"

          table_data << [i, "#{step_name},#{status_symbol},#{ran_status}"]
          failed_steps << step_name unless completion_status

          warnings.concat(step.warnings)
          notices.concat(step.notices)
        end
      end

      pool.shutdown
      pool.wait_for_termination
      puts ""

      sorted_table_data = table_data.sort_by(&:first).map(&:last)

      {failed_steps: failed_steps.to_a, table_data: sorted_table_data, warnings: warnings.to_a, notices: notices.to_a}
    end

    def display_results_table(table_data)
      csv_data = "Step,Status,Ran?\n" + table_data.join("\n")
      IO.popen(["gum", "table", "--border", "rounded", "--widths", "25,8,8", "--print"], "w") do |io|
        io.write(csv_data)
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
