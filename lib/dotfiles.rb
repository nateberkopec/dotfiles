#!/usr/bin/env ruby

require_relative "loader"

class ConfigLoader
  def initialize(dotfiles_dir)
    @dotfiles_dir = dotfiles_dir
    @config_dir = File.join(dotfiles_dir, "config")
  end

  def packages
    @packages ||= load_config("packages.yml")
  end

  def paths
    @paths ||= load_config("paths.yml")
  end

  def expand_path(path_key, category = "home_paths")
    path = paths.dig(category, path_key.to_s)
    return nil unless path
    File.expand_path(path)
  end

  def source_path(source_key)
    source = paths.dig("dotfiles_sources", source_key.to_s)
    return nil unless source
    File.join(@dotfiles_dir, source)
  end

  private

  def load_config(filename)
    config_path = File.join(@config_dir, filename)
    YAML.load_file(config_path)
  rescue Errno::ENOENT
    {}
  end
end

class Dotfiles
  attr_reader :dotfiles_repo, :dotfiles_dir, :home

  def initialize
    @debug = ENV["DEBUG"] == "true"
    @dotfiles_repo = "https://github.com/nateberkopec/dotfiles.git"
    @dotfiles_dir = File.expand_path("~/.dotfiles")
    @home = ENV["HOME"]

    setup_signal_handlers
  end

  def run
    debug "Starting macOS development environment setup..."

    step_params = {
      debug: @debug,
      dotfiles_repo: @dotfiles_repo,
      dotfiles_dir: @dotfiles_dir,
      home: @home
    }

    step_instances = []

    puts ""
    Step.all_steps.each do |step_class|
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
    display_1password_notice if result[:needs_1password_setup]
    display_homebrew_warnings(result[:skipped_packages], result[:skipped_casks])
    display_final_status(result[:failed_steps])
  end

  def collect_step_results(step_instances)
    failed_steps = []
    table_data = []
    skipped_packages = []
    skipped_casks = []
    needs_1password_setup = false

    Step.all_steps.each_with_index do |step_class, i|
      step = step_instances[i]
      step_name = step_class.display_name
      completion_status = !!step.complete?
      status_symbol = completion_status ? "✓" : "✗"
      ran_status = step.ran? ? "Yes" : "No"

      table_data << "#{step_name},#{status_symbol},#{ran_status}"
      failed_steps << step_name unless completion_status

      skipped_packages.concat(step.skipped_packages) if step.respond_to?(:skipped_packages) && step.skipped_packages.any?
      skipped_casks.concat(step.skipped_casks) if step.respond_to?(:skipped_casks) && step.skipped_casks.any?
      needs_1password_setup = true if step.respond_to?(:needs_manual_setup) && step.needs_manual_setup
    end

    {failed_steps: failed_steps, table_data: table_data, skipped_packages: skipped_packages, skipped_casks: skipped_casks, needs_1password_setup: needs_1password_setup}
  end

  def display_results_table(table_data)
    csv_data = "Step,Status,Ran?\n" + table_data.join("\n")
    IO.popen(["gum", "table", "--border", "rounded", "--widths", "25,8,8", "--print"], "w") do |io|
      io.write(csv_data)
    end
  end

  def display_1password_notice
    system("gum", "style", "--foreground", "#00aaff", "--border", "rounded", "--align", "left", "--width", "60", "--margin", "1 0", "--padding", "1 2", "ℹ️  1Password SSH Agent Setup Required", "", "To complete SSH setup:", "1. Open 1Password app", "2. Go to Settings → Developer", "3. Enable 'Use the SSH agent'")
  end

  def display_homebrew_warnings(packages, casks)
    return unless packages.any? || casks.any?

    warning_lines = ["⚠️  Homebrew Installation Skipped", "", "No admin rights detected."]
    warning_lines.concat(build_package_warnings(packages, "Skipped formulae:"))
    warning_lines.concat(build_package_warnings(casks, "Skipped casks:"))

    system("gum", "style", "--foreground", "#ffaa00", "--border", "rounded", "--align", "left", "--width", "60", "--margin", "1 0", "--padding", "1 2", *warning_lines)
  end

  def build_package_warnings(packages, header)
    return [] unless packages.any?
    ["", header] + packages.map { |pkg| "• #{pkg}" }
  end

  def display_final_status(failed_steps)
    if failed_steps.any?
      system("gum", "style", "--foreground", "#ff5555", "--border", "thick", "--align", "center", "--width", "60", "--margin", "1 0", "--padding", "1 2", "❌ Installation Failed!", "", "Incomplete steps:", *failed_steps.map { |step| "• #{step}" })
      exit 1
    else
      system("gum", "style", "--foreground", "#50fa7b", "--border", "rounded", "--align", "center", "--width", "50", "--margin", "1 0", "--padding", "1 2", "🎉 All Steps Complete!", "Setup successful")
    end
  end

  def debug(message)
    puts message if @debug
  end

  def command_exists?(command)
    system("command -v #{command} >/dev/null 2>&1")
  end

  def setup_signal_handlers
    trap("EXIT") do
      system("ssh-add -D 2>/dev/null") if command_exists?("ssh-add")
    end
  end
end
