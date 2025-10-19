require "fileutils"
require "open3"
require "config"
require "step"
Dir.glob(File.join(__dir__, "steps", "*.rb")).sort.each { |file| require file }

class Dotfiles
  class Updater
    def initialize
      dotfiles_dir = File.expand_path("~/.dotfiles")

      unless Dir.exist?(dotfiles_dir)
        puts "Error: Dotfiles directory not found at #{dotfiles_dir}"
        puts "Please run the initial setup script first."
        exit 1
      end

      @config = Config.new(dotfiles_dir)
    end

    def run
      puts "Updating dotfiles repository via step updates..."

      Dotfiles::Step.all_steps.each do |step_class|
        step = step_class.new(config: @config)
        step.update
      end

      commit_and_push_changes
    end

    private

    def commit_and_push_changes
      Dir.chdir(@config.dotfiles_dir)
      stdout, _stderr, _ = Open3.capture3("git status --porcelain")
      return puts "No changes to commit." if stdout.empty?

      system("git add -A")
      system("git diff --cached --stat")

      gc_ai_flags = ENV["GIT_COMMIT_FLAGS"] || ""
      gc_ai_cmd = "fish -c 'gc-ai #{gc_ai_flags}'"
      git_commit_cmd = "git commit #{gc_ai_flags} -m 'Update dotfiles from system'"

      system(gc_ai_cmd) || system(git_commit_cmd)

      puts "Dotfiles updated successfully!"
    end

    def command_exists?(cmd)
      system("command -v #{cmd} >/dev/null 2>&1")
    end
  end
end
