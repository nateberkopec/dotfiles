class Dotfiles::Step::ProtectFilesStep < Dotfiles::Step
  prepend Dotfiles::Step::Sudoable
  include Dotfiles::Step::Protectable

  macos_only

  def self.display_name
    "Protect Files"
  end

  def self.depends_on
    [Dotfiles::Step::SyncHomeDirectoryStep]
  end

  private

  def protected_files
    agent_hook_files + [gem_credentials_file]
  end

  def immutable_flag(file)
    return "uchg" if gem_credentials_file?(file)

    "schg"
  end

  def protect_with_sudo?(file)
    !gem_credentials_file?(file)
  end

  def protected_file_mode(file)
    return 0o600 if gem_credentials_file?(file)

    nil
  end

  def agent_hook_files
    [
      File.join(@home, ".agents", "hooks", "deny-rm-rf.jq"),
      File.join(@home, ".config", "opencode", "plugin", "deny-rm-rf.js"),
      File.join(@home, ".pi", "agent", "extensions", "find_timeout.ts")
    ]
  end

  def gem_credentials_file
    File.join(@home, ".gem", "credentials")
  end

  def gem_credentials_file?(file)
    file == gem_credentials_file
  end
end
