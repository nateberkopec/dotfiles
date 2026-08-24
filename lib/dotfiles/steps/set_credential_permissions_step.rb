class Dotfiles::Step::SetCredentialPermissionsStep < Dotfiles::Step
  DESCRIPTION = "Restricts credential files to their owner.".freeze
  MODE = 0o600

  macos_only

  def run
    credential_files.each do |file|
      @system.chmod(MODE, file) if @system.file_exist?(file)
    end
    nil
  end

  def complete?
    super
    credential_files.all? { |file| !@system.file_exist?(file) || file_mode(file) == "600" }
  end

  private

  def credential_files
    [File.join(@home, ".gem", "credentials"), File.join(@home, ".aws", "credentials")]
  end

  def file_mode(file)
    execute(command("stat", "-f", "%Lp", file)).first
  end
end
