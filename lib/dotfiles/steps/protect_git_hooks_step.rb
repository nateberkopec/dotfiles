class Dotfiles::Step::ProtectGitHooksStep < Dotfiles::Step
  prepend Dotfiles::Step::Sudoable

  macos_only

  def self.display_name
    "Protect Git Hooks"
  end

  def self.depends_on
    [Dotfiles::Step::SyncHomeDirectoryStep]
  end

  def run
    hook_files.each do |file|
      next unless @system.file_exist?(file)

      _, status = execute("chflags schg '#{file}'", sudo: true)
      add_error("Failed to protect #{file}") unless status == 0
    end
  end

  def complete?
    hook_files.all? { |file| !@system.file_exist?(file) || file_immutable?(file) }
  end

  private

  def hook_files
    [
      File.join(@home, ".git-hooks", "pre-commit"),
      File.join(@home, ".git-hooks", "pre-push")
    ]
  end

  def file_immutable?(file)
    output, status = execute("ls -lO '#{file}'")
    status == 0 && output.include?("schg")
  end
end
