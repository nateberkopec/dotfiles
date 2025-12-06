require "fileutils"
require "open3"
require "config"
require "step"
Dir.glob(File.join(__dir__, "steps", "*.rb")).sort.each { |file| require file }

class Dotfiles
  class Updater
    def initialize(log_file = nil)
      Dotfiles.log_file = log_file
      @debug = ENV["DEBUG"] == "true"
      @config = Config.new(Dotfiles.determine_dotfiles_dir)
    end

    def run
      puts "Updating dotfiles repository via step updates..."

      step_params = {
        debug: @debug,
        dotfiles_repo: @config.dotfiles_repo,
        dotfiles_dir: @config.dotfiles_dir,
        home: @config.home
      }

      Dotfiles::Step.all_steps.each do |step_class|
        step = step_class.new(**step_params)
        # Each step may implement update to sync back into repo
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

      return puts "Commit cancelled." unless system("gum confirm 'Proceed with commit?'")

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
