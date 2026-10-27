require "csv"

class Dotfiles
  class OutputFormatter
    def initialize(results, popen_call: IO.method(:popen), system_call: Kernel.method(:system), exit_call: Kernel.method(:exit), output: $stdout, log_call: Dotfiles.method(:debug))
      @results = results
      @log_call = log_call
      @popen_call = popen_call
      @system_call = system_call
      @exit_call = exit_call
      @output = output
    end

    def display
      log_results
      display_results_table
      display_errors
      display_warnings
      display_notices
      display_final_status
    end

    private

    def log_results
      @results[:errors].each { |err| @log_call.call("Error in #{err[:step]}: #{err[:message]}") }
      {"Warning" => @results[:warnings], "Notice" => @results[:notices]}.each do |label, messages|
        messages.each { |msg| @log_call.call("#{label}: #{msg[:title]}: #{msg[:message]}") }
      end
      failed = @results[:failed_steps]
      @log_call.call(failed.any? ? "Incomplete steps: #{failed.join(", ")}" : "All steps complete")
    end

    def display_results_table
      csv_data = CSV.generate do |csv|
        csv << ["Step", "Status", "Ran?"]
        @results[:table_data].each { |row| csv << row }
      end
      @popen_call.call(["gum", "table", "--border", "rounded", "--widths", "25,8,8", "--print"], "w") { |io| io.write(csv_data) }
    end

    def display_errors
      return if @results[:errors].empty?
      @results[:errors].group_by { |err| err[:step] }.each { |step, errs| display_step_errors(step, errs) }
    end

    def display_step_errors(step_name, step_errors)
      @output.puts "\n❌ #{step_name}"
      step_errors.each { |err| @output.puts err[:message], "" }
    end

    def display_warnings
      display_messages(@results[:warnings], "#ffaa00")
    end

    def display_notices
      display_messages(@results[:notices], "#00aaff")
    end

    def display_messages(messages, color)
      messages.each { |msg| gum_style(color, [msg[:title], "", msg[:message]]) }
    end

    def display_final_status
      @results[:failed_steps].any? ? display_failure : display_success
    end

    def display_failure
      failed = @results[:failed_steps]
      gum_style("#ff5555", ["❌ Installation Failed!", "", "Incomplete steps:", *failed.map { |s| "• #{s}" }], border: "thick")
      @exit_call.call(1)
    end

    def display_success
      attention = @results[:warnings].size + @results[:notices].size
      status = attention.zero? ? "Setup successful" : "#{attention} item(s) above need attention"
      gum_style("#50fa7b", ["🎉 All Steps Complete!", status], width: 50)
    end

    def gum_style(color, lines, border: "rounded", width: 60)
      @system_call.call("gum", "style", "--foreground", color, "--border", border, "--align", "left", "--width", width.to_s, "--margin", "1 0", "--padding", "1 2", *lines)
    end
  end
end
