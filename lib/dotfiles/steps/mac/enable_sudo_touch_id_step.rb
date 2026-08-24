class Dotfiles::Step::EnableSudoTouchIDStep < Dotfiles::Step
  DESCRIPTION = "Enables Touch ID authentication for sudo.".freeze

  prepend Dotfiles::Step::Sudoable

  macos_only

  def run
    return add_error("Refusing to replace existing #{target_path}") if @system.file_exist?(target_path)

    _, status = execute(command("install", "-o", "root", "-g", "wheel", "-m", "0444", source_path, target_path), sudo: true)
    add_error("Failed to enable Touch ID for sudo") unless status == 0
  end

  def complete?
    super
    add_error("Touch ID is not enabled for sudo") unless enabled?
    @errors.empty?
  end

  private

  def enabled?
    @system.file_exist?(target_path) && @system.readlines(target_path).any? { |line| line.split == %w[auth sufficient pam_tid.so] }
  end

  def source_path
    File.join(@dotfiles_dir, "files", "templates", "sudo_local")
  end

  def target_path
    "/etc/pam.d/sudo_local"
  end
end
