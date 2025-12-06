require "fileutils"
require "open3"
require "config"
require "step"
Dir.glob(File.join(__dir__, "steps", "*.rb")).sort.each { |file| require file }

class Dotfiles
  class Updater
    def initialize
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

      run_security_scan

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

    def run_security_scan
      return unless command_exists?("llm")

      puts "\nRunning security scan for secrets..."

      diff, _stderr, status = Open3.capture3("git diff --cached")
      return if !status.success? || diff.empty?

      prompt = <<~PROMPT
        You are a security scanner. Analyze this git diff for secrets, credentials, or sensitive information that should not be committed to a repository.

        Look for:
        - API keys, tokens, or passwords
        - Private keys or certificates
        - Database connection strings with credentials
        - AWS/GCP/Azure credentials
        - OAuth tokens or secrets
        - Any hardcoded sensitive values

        If you find potential secrets, list each one with the file and line.
        If the diff looks safe, simply say "No secrets detected."

        Be concise. Only report actual concerns, not false positives like example values or placeholders.
      PROMPT

      result, _stderr, _status = Open3.capture3("llm", "-s", prompt, stdin_data: diff)

      puts "\n"
      system("gum style --border rounded --padding '1 2' --border-foreground '#ffcc00' '🔍 Security Scan Result' '' '#{result.gsub("'", "'\\''").strip}'")
      puts "\n"
    end
  end
end
