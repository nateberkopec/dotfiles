class Dotfiles::Step::SyncClaudeConfigStep < Dotfiles::Step
  def self.display_name
    "Claude Configuration"
  end

  def run
    debug "Syncing Claude configuration..."
    source = dotfiles_source("claude_config")
    dest = app_path("claude_config")
    @system.mkdir_p(File.dirname(dest))
    @system.cp(source, dest)
  end

  def complete?
    super
    source = dotfiles_source("claude_config")
    dest = app_path("claude_config")

    add_error("Claude config source path not configured") unless source
    add_error("Claude config destination path not configured") unless dest
    return false if @errors.any?

    add_error("Claude config source does not exist at #{source}") unless @system.file_exist?(source)
    return false if @errors.any?

    add_error("Claude config is not synced") unless files_match?(source, dest)
    @errors.empty?
  end

  def update
    source = app_path("claude_config")
    dest = dotfiles_source("claude_config")
    copy_if_exists(source, dest)
  end
end
