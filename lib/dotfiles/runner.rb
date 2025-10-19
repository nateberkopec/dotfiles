class Dotfiles
  class Runner
    attr_reader :dotfiles_repo, :dotfiles_dir, :home

    def initialize
      @debug = ENV["DEBUG"] == "true"
      @dotfiles_dir = File.expand_path("~/.dotfiles")
      @home = ENV["HOME"]
      @config = Config.new(@dotfiles_dir)
      @dotfiles_repo = @config.dotfiles_repo
    end

    def run
      Dotfiles.debug "Starting macOS development environment setup..."

      step_params = {
        debug: @debug,
        dotfiles_repo: @dotfiles_repo,
        dotfiles_dir: @dotfiles_dir,
        home: @home
      }

      step_instances = []

      puts ""
      Dotfiles::Step.all_steps.each do |step_class|
        step = step_class.new(**step_params)
        step_instances << step
        if step.should_run?
          printf "X"
          step.instance_variable_set(:@ran, true)
          step.run
        else
          printf "."
        end
      end
      puts ""

      check_completion(step_params, step_instances)
    rescue => e
      puts "Error: #{e.message}"
      exit 1
    end

    private

    def check_completion(step_params, step_instances)
      result = collect_step_results(step_instances)
      display_results_table(result[:table_data])
      display_warnings(result[:warnings])
      display_notices(result[:notices])
      display_final_status(result[:failed_steps])
    end

    def collect_step_results(step_instances)
      failed_steps = []
      table_data = []
      warnings = []
      notices = []

      Dotfiles::Step.all_steps.each_with_index do |step_class, i|
        step = step_instances[i]
        step_name = step_class.display_name
        completion_status = !!step.complete?
        status_symbol = completion_status ? "✓" : "✗"
        ran_status = step.ran? ? "Yes" : "No"

        table_data << "#{step_name},#{status_symbol},#{ran_status}"
        failed_steps << step_name unless completion_status

        warnings.concat(step.warnings)
        notices.concat(step.notices)
      end

      {failed_steps: failed_steps, table_data: table_data, warnings: warnings, notices: notices}
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
