class Dotfiles::Step::ProtectGitHooksStep < Dotfiles::Step
  DESCRIPTION = "Protects safety hook files with immutable flags.".freeze

  prepend Dotfiles::Step::Sudoable
  include Dotfiles::Step::Protectable

  macos_only

  def self.display_name
    "Protect Git Hooks"
  end

  private

  def protected_files
    [
      File.join(@home, ".git-hooks", "pre-commit"),
      File.join(@home, ".git-hooks", "pre-push")
    ]
  end
end
