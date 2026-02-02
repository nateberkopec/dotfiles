class Dotfiles::Step::ProtectGitHooksStep < Dotfiles::Step
  prepend Dotfiles::Step::Sudoable
  include Dotfiles::Step::Protectable

  macos_only

  def self.display_name
    "Protect Git Hooks"
  end

  def self.depends_on
    [Dotfiles::Step::SyncHomeDirectoryStep]
  end

  private

  def hook_files
    [
      File.join(@home, ".git-hooks", "pre-commit"),
      File.join(@home, ".git-hooks", "pre-push")
    ]
  end
end
