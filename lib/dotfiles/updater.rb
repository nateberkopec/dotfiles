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
      run_all_step_updates
      commit_and_push_changes
    end

    def run_all_step_updates
      Dotfiles::Step.all_steps.each { |step_class| step_class.new(**step_params).update }
    end

    def step_params
      {debug: @debug, dotfiles_repo: @config.dotfiles_repo, dotfiles_dir: @config.dotfiles_dir, home: @config.home}
    end

    private

    def commit_and_push_changes
      Dir.chdir(@config.dotfiles_dir)
      return puts "No changes to commit." if git_status_clean?
      stage_and_review_changes
      return puts "Commit cancelled." unless confirm_commit?
      create_commit
      puts "Dotfiles updated successfully!"
    end

    def git_status_clean?
      stdout, = Open3.capture3("git status --porcelain")
      stdout.empty?
    end

    def stage_and_review_changes
      system("git add -A")
      system("git diff --cached --stat")
      run_security_scan
    end

    def confirm_commit?
      system("gum confirm 'Proceed with commit?'")
    end

    def create_commit
      flags = ENV["GIT_COMMIT_FLAGS"] || ""
      system("git commit #{flags} -m 'Update dotfiles from system'")
    end

    def command_exists?(cmd)
      system("command -v #{cmd} >/dev/null 2>&1")
    end

    def run_security_scan
      return unless command_exists?("llm")
      diff = fetch_cached_diff
      return if diff.nil? || diff.empty?
      display_scan_result(scan_diff_for_secrets(diff))
    end

    def fetch_cached_diff
      puts "\nRunning security scan for secrets..."
      diff, _stderr, status = Open3.capture3("git diff --cached")
      status.success? ? diff : nil
    end

    def scan_diff_for_secrets(diff)
      result, = Open3.capture3("llm", "-s", security_scan_prompt, stdin_data: diff)
      result
    end

    def display_scan_result(result)
      puts "\n"
      system("gum style --border rounded --padding '1 2' --border-foreground '#ffcc00' '🔍 Security Scan Result' '' '#{result.gsub("'", "'\\''").strip}'")
      puts "\n"
    end

    def security_scan_prompt
      <<~PROMPT
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
    end
  end
end
