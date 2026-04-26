class Dotfiles::Step::ProtectFilesStep < Dotfiles::Step
  DESCRIPTION = "Protects sensitive generated files with immutable flags and strict permissions.".freeze

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
    pi_extension_files + user_credentials_files
  end

  def immutable_flag(file)
    return "uchg" if user_credentials_file?(file)

    "schg"
  end

  def protect_with_sudo?(file)
    !user_credentials_file?(file)
  end

  def protected_file_mode(file)
    return 0o600 if user_credentials_file?(file)

    nil
  end

  def pi_extension_files
    [File.join(@home, ".pi", "agent", "extensions", "find_timeout.ts")]
  end

  def user_credentials_files
    [gem_credentials_file, aws_credentials_file]
  end

  def gem_credentials_file
    File.join(@home, ".gem", "credentials")
  end

  def aws_credentials_file
    File.join(@home, ".aws", "credentials")
  end

  def user_credentials_file?(file)
    user_credentials_files.include?(file)
  end
end
