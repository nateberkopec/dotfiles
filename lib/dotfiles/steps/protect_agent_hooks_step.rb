class Dotfiles::Step::ProtectAgentHooksStep < Dotfiles::Step
  macos_only

  def self.display_name
    "Protect Agent Hooks"
  end

  def self.depends_on
    [Dotfiles::Step::SyncHomeDirectoryStep]
  end

  def run
    hook_files.each do |file|
      next unless @system.file_exist?(file)

      execute("chflags schg '#{file}'", sudo: true)
    end
  end

  def complete?
    return true if ci_or_noninteractive?

    hook_files.all? { |file| !@system.file_exist?(file) || file_immutable?(file) }
  end

  private

  def hook_files
    [
      File.join(@home, ".claude", "hooks", "deny-rm-rf.jq"),
      File.join(@home, ".config", "opencode", "plugin", "deny-rm-rf.js")
    ]
  end

  def file_immutable?(file)
    output, status = execute("ls -lO '#{file}'")
    status == 0 && output.include?("schg")
  end
end
