class Dotfiles::Step::ProtectAgentHooksStep < Dotfiles::Step
  prepend Dotfiles::Step::Sudoable
  include Dotfiles::Step::Protectable

  macos_only

  def self.display_name
    "Protect Agent Hooks"
  end

  def self.depends_on
    [Dotfiles::Step::SyncHomeDirectoryStep]
  end

  private

  def hook_files
    [
      File.join(@home, ".claude", "hooks", "deny-rm-rf.jq"),
      File.join(@home, ".config", "opencode", "plugin", "deny-rm-rf.js")
    ]
  end
end
