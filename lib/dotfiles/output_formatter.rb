require "csv"

class Dotfiles
  class OutputFormatter
    def initialize(results)
      @results = results
    end

    def display
      display_results_table
      display_errors
      display_warnings
      display_notices
      display_final_status
    end

    private

    def display_results_table
      csv_data = CSV.generate do |csv|
        csv << ["Step", "Status", "Ran?"]
        @results[:table_data].each { |row| csv << row }
      end
      IO.popen(["gum", "table", "--border", "rounded", "--widths", "25,8,8", "--print"], "w") { |io| io.write(csv_data) }
    end

    def display_errors
      return if @results[:errors].empty?
      @results[:errors].group_by { |err| err[:step] }.each { |step, errs| display_step_errors(step, errs) }
    end

    def display_step_errors(step_name, step_errors)
      message_lines = ["❌ #{step_name}", "", *step_errors.map { |err| "• #{err[:message]}" }]
      gum_style("#ff5555", message_lines)
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
